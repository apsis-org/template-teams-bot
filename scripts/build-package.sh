#!/usr/bin/env bash
set -euo pipefail

# Builds the Teams app package
# Prerequisite: terraform apply has been run
# Usage: make build-package

APP_PACKAGE_DIR="appPackage"

# --- Choose the environment ---
echo "Choose the environment to build the Teams app package for."
echo "  stg  : staging"
echo "  prod : production"
echo ""
read -rp "Environment (default: stg): " ENV
ENV="${ENV:-stg}"
OUTPUT_ZIP="teams-app-${ENV}.zip"
ENV_SUFFIX="$([[ "$ENV" == "prod" ]] && echo "" || echo " [${ENV}]")"

# --- Get BOT_ID from terraform output ---
echo ""
echo "--- Fetching the Bot App ID... ---"

INFRA_DIR="infra/envs/${ENV}"
if [[ ! -d "$INFRA_DIR" ]]; then
  echo "Error: ${INFRA_DIR} not found" >&2
  exit 1
fi

BOT_ID="$(cd "$INFRA_DIR" && terraform output -raw microsoft_app_id)"

if [[ -z "$BOT_ID" ]]; then
  echo "Error: could not read microsoft_app_id. Make sure terraform apply has been run" >&2
  exit 1
fi

echo "  BOT_ID: ${BOT_ID}"

# --- Generate TEAMS_APP_ID (UUID) ---
TEAMS_APP_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"

# --- Substitute placeholders in manifest.json inside a temp directory ---
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

# --- Zip ---
echo "--- Building the package... ---"
(cd "$TMPDIR" && zip -r - manifest.json color.png outline.png) > "$OUTPUT_ZIP"

echo ""
echo "=== Created $(pwd)/${OUTPUT_ZIP} ==="
echo ""
echo "Upload it to Teams as follows:"
echo "  Teams client → Apps → Manage your apps → Upload an app → select $(pwd)/${OUTPUT_ZIP}"
