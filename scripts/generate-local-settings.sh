#!/usr/bin/env bash
set -euo pipefail

# Key Vault からボット認証情報を取得し local.settings.json に反映するスクリプト
# ローカル開発用に stg の Microsoft* 値を書き込みます。
# 既存の local.settings.json がある場合は Microsoft* 以外のキーは保持します。
# 前提: az login 済み、stg の terraform apply 済み、jq インストール済み
# 使い方: make generate-local-settings

TFVARS_FILE="infra/envs/terraform.tfvars"
OUTPUT_FILE="local.settings.json"
EXAMPLE_FILE="local.settings.json.example"
ENVIRONMENT="stg"

if ! command -v jq &> /dev/null; then
  echo "エラー: jq がインストールされていません。brew install jq でインストールしてください" >&2
  exit 1
fi

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "エラー: ${TFVARS_FILE} が見つかりません。先に作成してください" >&2
  exit 1
fi

PROJECT_NAME="$(grep "^project_name" "$TFVARS_FILE" | sed 's/.*= *"\([^"]*\)".*/\1/')"
if [[ -z "$PROJECT_NAME" ]]; then
  echo "エラー: ${TFVARS_FILE} から project_name を取得できませんでした" >&2
  exit 1
fi

VAULT_NAME="kv-${PROJECT_NAME//-/}${ENVIRONMENT}"

echo "--- Key Vault '${VAULT_NAME}' からシークレットを取得中... ---"

MICROSOFT_APP_ID="$(az keyvault secret show --vault-name "$VAULT_NAME" --name MicrosoftAppId --query value -o tsv)"
MICROSOFT_APP_PASSWORD="$(az keyvault secret show --vault-name "$VAULT_NAME" --name MicrosoftAppPassword --query value -o tsv)"
MICROSOFT_APP_TENANT_ID="$(az account show --query tenantId -o tsv)"

if [[ -z "$MICROSOFT_APP_ID" || -z "$MICROSOFT_APP_PASSWORD" ]]; then
  echo "エラー: Key Vault からシークレットを取得できませんでした" >&2
  exit 1
fi

# ベースファイルを選択（既存 OUTPUT_FILE があればそれを merge、無ければ .example から生成）
if [[ -f "$OUTPUT_FILE" ]]; then
  BASE_FILE="$OUTPUT_FILE"
  echo "--- 既存の ${OUTPUT_FILE} の Microsoft* 以外の値は保持します ---"
elif [[ -f "$EXAMPLE_FILE" ]]; then
  BASE_FILE="$EXAMPLE_FILE"
  echo "--- ${EXAMPLE_FILE} をベースに ${OUTPUT_FILE} を生成します ---"
else
  echo "エラー: ${OUTPUT_FILE} も ${EXAMPLE_FILE} も見つかりません" >&2
  exit 1
fi

# jq で Microsoft* フィールドだけ上書き
TMPFILE="$(mktemp)"
jq \
  --arg id "$MICROSOFT_APP_ID" \
  --arg pass "$MICROSOFT_APP_PASSWORD" \
  --arg tenant "$MICROSOFT_APP_TENANT_ID" \
  '.Values.MicrosoftAppId = $id
   | .Values.MicrosoftAppPassword = $pass
   | .Values.MicrosoftAppType = "SingleTenant"
   | .Values.MicrosoftAppTenantId = $tenant' \
  "$BASE_FILE" > "$TMPFILE"
mv "$TMPFILE" "$OUTPUT_FILE"

echo ""
echo "=== ${OUTPUT_FILE} を更新しました ==="
echo "  MicrosoftAppId       : ${MICROSOFT_APP_ID}"
echo "  MicrosoftAppType     : SingleTenant"
echo "  MicrosoftAppTenantId : ${MICROSOFT_APP_TENANT_ID}"
echo "  MicrosoftAppPassword : (masked)"
