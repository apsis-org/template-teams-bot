#!/usr/bin/env bash
set -euo pipefail

# appPackage/manifest.json のボット名を設定するスクリプト
# 使い方: make setup-manifest

MANIFEST_FILE="appPackage/manifest.json"

if ! command -v jq &> /dev/null; then
  echo "エラー: jq がインストールされていません。brew install jq でインストールしてください" >&2
  exit 1
fi

echo "Teams アプリのボット名を設定します。"
echo ""
read -rp "ボット名を入力してください（例: 社内サポートボット）: " BOT_NAME

if [[ -z "$BOT_NAME" ]]; then
  echo "エラー: ボット名を入力してください" >&2
  exit 1
fi

TMPFILE="$(mktemp)"
jq \
  --arg short "${BOT_NAME}__ENV_SUFFIX__" \
  --arg full "${BOT_NAME}__ENV_SUFFIX__" \
  '.name.short = $short | .name.full = $full' \
  "$MANIFEST_FILE" > "$TMPFILE"
mv "$TMPFILE" "$MANIFEST_FILE"

echo ""
echo "=== manifest.json を更新しました ==="
echo "  ボット名（stg）: ${BOT_NAME} [stg]"
echo "  ボット名（prod）: ${BOT_NAME}"
