#!/usr/bin/env bash
set -euo pipefail

# Fetches the bot credentials from Key Vault and writes them to local.settings.json
# Writes the stg Microsoft* values for local development.
# If local.settings.json already exists, keys other than Microsoft* are preserved.
# Prerequisites: az login done, terraform apply done for stg, jq installed
# Usage: make generate-local-settings

TFVARS_FILE="infra/envs/terraform.tfvars"
OUTPUT_FILE="local.settings.json"
EXAMPLE_FILE="local.settings.json.example"
ENVIRONMENT="stg"

if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Install it with: brew install jq" >&2
  exit 1
fi

if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "Error: ${TFVARS_FILE} not found. Create it first" >&2
  exit 1
fi

PROJECT_NAME="$(grep "^project_name" "$TFVARS_FILE" | sed 's/.*= *"\([^"]*\)".*/\1/')"
if [[ -z "$PROJECT_NAME" ]]; then
  echo "Error: could not read project_name from ${TFVARS_FILE}" >&2
  exit 1
fi

VAULT_NAME="kv-${PROJECT_NAME//-/}${ENVIRONMENT}"

echo "--- Fetching secrets from Key Vault '${VAULT_NAME}'... ---"

MICROSOFT_APP_ID="$(az keyvault secret show --vault-name "$VAULT_NAME" --name MicrosoftAppId --query value -o tsv)"
MICROSOFT_APP_PASSWORD="$(az keyvault secret show --vault-name "$VAULT_NAME" --name MicrosoftAppPassword --query value -o tsv)"
MICROSOFT_APP_TENANT_ID="$(az account show --query tenantId -o tsv)"

if [[ -z "$MICROSOFT_APP_ID" || -z "$MICROSOFT_APP_PASSWORD" ]]; then
  echo "Error: could not fetch the secrets from Key Vault" >&2
  exit 1
fi

# Pick the base file (merge into the existing OUTPUT_FILE if present, otherwise start from the .example)
if [[ -f "$OUTPUT_FILE" ]]; then
  BASE_FILE="$OUTPUT_FILE"
  echo "--- Keeping non-Microsoft* values of the existing ${OUTPUT_FILE} ---"
elif [[ -f "$EXAMPLE_FILE" ]]; then
  BASE_FILE="$EXAMPLE_FILE"
  echo "--- Generating ${OUTPUT_FILE} from ${EXAMPLE_FILE} ---"
else
  echo "Error: neither ${OUTPUT_FILE} nor ${EXAMPLE_FILE} found" >&2
  exit 1
fi

# Overwrite only the Microsoft* fields with jq
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
echo "=== Updated ${OUTPUT_FILE} ==="
echo "  MicrosoftAppId       : ${MICROSOFT_APP_ID}"
echo "  MicrosoftAppType     : SingleTenant"
echo "  MicrosoftAppTenantId : ${MICROSOFT_APP_TENANT_ID}"
echo "  MicrosoftAppPassword : (masked)"
