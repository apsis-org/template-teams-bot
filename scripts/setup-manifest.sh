#!/usr/bin/env bash
set -euo pipefail

# Sets the bot name in appPackage/manifest.json
# Usage: make setup-manifest

MANIFEST_FILE="appPackage/manifest.json"

if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Install it with: brew install jq" >&2
  exit 1
fi

echo "Set the bot name for the Teams app."
echo ""
read -rp "Bot name (e.g. Internal Support Bot): " BOT_NAME

if [[ -z "$BOT_NAME" ]]; then
  echo "Error: the bot name must not be empty" >&2
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
echo "=== Updated manifest.json ==="
echo "  Bot name (stg):  ${BOT_NAME} [stg]"
echo "  Bot name (prod): ${BOT_NAME}"
