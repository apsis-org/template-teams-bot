#!/usr/bin/env bash
set -euo pipefail

# Teams アプリパッケージを生成するスクリプト
# 前提: terraform apply 済み
# 使い方: make build-package

APP_PACKAGE_DIR="appPackage"

# --- 環境の選択 ---
echo "Teams アプリパッケージを生成する環境を選択してください。"
echo "  stg  : ステージング環境"
echo "  prod : 本番環境"
echo ""
read -rp "環境を入力してください（デフォルト: stg）: " ENV
ENV="${ENV:-stg}"
OUTPUT_ZIP="teams-app-${ENV}.zip"
ENV_SUFFIX="$([[ "$ENV" == "prod" ]] && echo "" || echo " [${ENV}]")"

# --- terraform output から BOT_ID を取得 ---
echo ""
echo "--- Bot App ID を取得中... ---"

INFRA_DIR="infra/envs/${ENV}"
if [[ ! -d "$INFRA_DIR" ]]; then
  echo "エラー: ${INFRA_DIR} が見つかりません" >&2
  exit 1
fi

BOT_ID="$(cd "$INFRA_DIR" && terraform output -raw microsoft_app_id)"

if [[ -z "$BOT_ID" ]]; then
  echo "エラー: microsoft_app_id を取得できませんでした。terraform apply 済みか確認してください" >&2
  exit 1
fi

echo "  BOT_ID: ${BOT_ID}"

# --- TEAMS_APP_ID を生成（UUID）---
TEAMS_APP_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"

# --- manifest.json を一時ディレクトリで置換 ---
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cp "${APP_PACKAGE_DIR}/manifest.json" "${TMPDIR}/manifest.json"
cp "${APP_PACKAGE_DIR}/color.png" "${TMPDIR}/color.png"
cp "${APP_PACKAGE_DIR}/outline.png" "${TMPDIR}/outline.png"

sed -i.bak \
  -e "s/__BOT_ID__/${BOT_ID}/g" \
  -e "s/__TEAMS_APP_ID__/${TEAMS_APP_ID}/g" \
  -e "s/__ENV_SUFFIX__/${ENV_SUFFIX}/g" \
  "${TMPDIR}/manifest.json"
rm "${TMPDIR}/manifest.json.bak"

# --- ZIP 化 ---
echo "--- パッケージを生成中... ---"
(cd "$TMPDIR" && zip -r - manifest.json color.png outline.png) > "$OUTPUT_ZIP"

echo ""
echo "=== $(pwd)/${OUTPUT_ZIP} を生成しました ==="
echo ""
echo "以下の手順で Teams にアップロードしてください："
echo "  Teams クライアント → アプリ → アプリを管理 → アプリをアップロード → $(pwd)/${OUTPUT_ZIP} を選択"
