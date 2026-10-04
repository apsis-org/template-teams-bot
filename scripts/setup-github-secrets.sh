#!/usr/bin/env bash
set -euo pipefail

# GitHub Actions で使用する Secrets / Variables を登録するスクリプト
# 前提: az login 済み（sp-github-actions のクライアントシークレット取得済み）、gh auth login 済み、terraform apply 済み
# 使い方: make setup-secrets

TFVARS_FILE="infra/envs/terraform.tfvars"

# --- 対話入力 ---
echo "GitHub Actions のデプロイ設定を行う環境を選択してください。"
echo "  stg  : ステージング環境（動作確認用）"
echo "  prod : 本番環境"
echo ""
read -rp "環境を入力してください（デフォルト: stg）: " ENV
ENV="${ENV:-stg}"

echo ""
echo "=== GitHub Environment: ${ENV} ==="
echo ""

# --- terraform.tfvars から値を取得 ---
if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "エラー: ${TFVARS_FILE} が見つかりません。先に作成してください" >&2
  exit 1
fi

PROJECT_NAME="$(grep "^project_name" "$TFVARS_FILE" | sed 's/.*= *"\([^"]*\)".*/\1/')"
RESOURCE_GROUP="rg-${PROJECT_NAME}-${ENV}"
FUNCTION_APP_NAME="func-${PROJECT_NAME}-${ENV}"

echo "  Function App: ${FUNCTION_APP_NAME}"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo ""

# --- 組織共通 Key Vault から sp-github-actions の情報を取得 ---
SHARED_VAULT_NAME="$(grep "^shared_key_vault_name" "$TFVARS_FILE" | sed 's/.*= *"\([^"]*\)".*/\1/')"

if [[ -z "$SHARED_VAULT_NAME" ]]; then
  echo "エラー: terraform.tfvars に shared_key_vault_name が設定されていません" >&2
  exit 1
fi

echo "--- Key Vault (${SHARED_VAULT_NAME}) から認証情報を取得中... ---"
CLIENT_ID="$(az keyvault secret show --vault-name "$SHARED_VAULT_NAME" --name sp-github-actions-client-id --query value -o tsv)"
CLIENT_SECRET="$(az keyvault secret show --vault-name "$SHARED_VAULT_NAME" --name sp-github-actions-client-secret --query value -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

AZURE_CREDENTIALS=$(cat <<EOF
{
  "clientId": "${CLIENT_ID}",
  "clientSecret": "${CLIENT_SECRET}",
  "tenantId": "${TENANT_ID}",
  "subscriptionId": "${SUBSCRIPTION_ID}"
}
EOF
)

# --- GitHub Environment を用意（存在しなければ作成、存在すれば no-op）---
echo ""
echo "--- GitHub Environment '${ENV}' を用意中... ---"
gh api --method PUT "repos/{owner}/{repo}/environments/${ENV}" > /dev/null

# --- GitHub に登録 ---
echo ""
echo "--- GitHub に登録中... ---"

MICROSOFT_APP_ID="$(cd "infra/envs/${ENV}" && terraform output -raw microsoft_app_id)"

gh secret set AZURE_CREDENTIALS --body "$AZURE_CREDENTIALS"
gh variable set AZURE_FUNCTION_APP_NAME --env "$ENV" --body "$FUNCTION_APP_NAME"
gh variable set AZURE_RESOURCE_GROUP --env "$ENV" --body "$RESOURCE_GROUP"
gh variable set MICROSOFT_APP_ID --env "$ENV" --body "$MICROSOFT_APP_ID"

# --- 環境別ランタイム値の登録（Function App の App Settings に流れる値）---
# 対象キーは .env.example に列挙されたものだけ（キー一覧の Single Source of Truth）。
# 値は .env.${ENV} から読み込み、GitHub Environment Secret に登録する。
# デプロイ時に deploy-functions.yml が同じキー一覧を使って Function App の App Settings に反映する。
ENV_EXAMPLE_FILE=".env.example"
ENV_FILE=".env.${ENV}"

# .env.example から KEY=... 形式の行のキー名だけを抽出（コメント・空行は除外）
RUNTIME_KEYS="$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_EXAMPLE_FILE" | tr -d '=' || true)"

if [[ -z "$RUNTIME_KEYS" ]]; then
  echo ""
  echo "--- ランタイム設定: ${ENV_EXAMPLE_FILE} にキーが定義されていないためスキップします ---"
elif [[ ! -f "$ENV_FILE" ]]; then
  echo ""
  echo "警告: ${ENV_FILE} が見つからないため、ランタイム値の登録をスキップします" >&2
  echo "  cp ${ENV_EXAMPLE_FILE} ${ENV_FILE} して値を設定後、再度このスクリプトを実行してください" >&2
else
  echo ""
  echo "--- ランタイム設定の登録（${ENV_FILE} → Environment: ${ENV}）---"

  # サブシェル内で .env.${ENV} を source し、.env.example にあるキーだけ gh に登録する
  (
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a

    for name in $RUNTIME_KEYS; do
      value="${!name:-}"
      if [[ -n "$value" ]]; then
        gh secret set "$name" --env "$ENV" --body "$value"
        echo "  ✓ ${name}"
      else
        echo "  - ${name} （空のためスキップ）"
      fi
    done
  )
fi

echo ""
echo "=== ${ENV} 環境のセットアップが完了しました ==="
