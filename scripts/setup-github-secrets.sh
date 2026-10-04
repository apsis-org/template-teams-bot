#!/usr/bin/env bash
set -euo pipefail

# Registers the Secrets / Variables used by GitHub Actions
# Prerequisites: az login done (with access to the sp-github-actions client secret), gh auth login done, terraform apply done
# Usage: make setup-secrets

TFVARS_FILE="infra/envs/terraform.tfvars"

# --- Interactive input ---
echo "Choose the environment to configure GitHub Actions deployment for."
echo "  stg  : staging (for verification)"
echo "  prod : production"
echo ""
read -rp "Environment (default: stg): " ENV
ENV="${ENV:-stg}"

echo ""
echo "=== GitHub Environment: ${ENV} ==="
echo ""

# --- Read values from terraform.tfvars ---
if [[ ! -f "$TFVARS_FILE" ]]; then
  echo "Error: ${TFVARS_FILE} not found. Create it first" >&2
  exit 1
fi

PROJECT_NAME="$(grep "^project_name" "$TFVARS_FILE" | sed 's/.*= *"\([^"]*\)".*/\1/')"
RESOURCE_GROUP="rg-${PROJECT_NAME}-${ENV}"
FUNCTION_APP_NAME="func-${PROJECT_NAME}-${ENV}"

echo "  Function App: ${FUNCTION_APP_NAME}"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo ""

# --- Fetch the sp-github-actions credentials from the organization-wide Key Vault ---
SHARED_VAULT_NAME="$(grep "^shared_key_vault_name" "$TFVARS_FILE" | sed 's/.*= *"\([^"]*\)".*/\1/')"

if [[ -z "$SHARED_VAULT_NAME" ]]; then
  echo "Error: shared_key_vault_name is not set in terraform.tfvars" >&2
  exit 1
fi

echo "--- Fetching credentials from Key Vault (${SHARED_VAULT_NAME})... ---"
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

# --- Ensure the GitHub Environment exists (created if missing, no-op otherwise) ---
echo ""
echo "--- Preparing GitHub Environment '${ENV}'... ---"
gh api --method PUT "repos/{owner}/{repo}/environments/${ENV}" > /dev/null

# --- Register in GitHub ---
echo ""
echo "--- Registering in GitHub... ---"

MICROSOFT_APP_ID="$(cd "infra/envs/${ENV}" && terraform output -raw microsoft_app_id)"

gh secret set AZURE_CREDENTIALS --body "$AZURE_CREDENTIALS"
gh variable set AZURE_FUNCTION_APP_NAME --env "$ENV" --body "$FUNCTION_APP_NAME"
gh variable set AZURE_RESOURCE_GROUP --env "$ENV" --body "$RESOURCE_GROUP"
gh variable set MICROSOFT_APP_ID --env "$ENV" --body "$MICROSOFT_APP_ID"

# --- Register per-environment runtime values (applied to the Function App's App Settings) ---
# Only the keys listed in .env.example are considered (single source of truth for the key list).
# Values are read from .env.${ENV} and registered as GitHub Environment Secrets.
# At deploy time, deploy-functions.yml uses the same key list to apply them to the Function App.
ENV_EXAMPLE_FILE=".env.example"
ENV_FILE=".env.${ENV}"

# Extract key names from lines of the form KEY=... in .env.example (comments and blank lines are ignored)
RUNTIME_KEYS="$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_EXAMPLE_FILE" | tr -d '=' || true)"

if [[ -z "$RUNTIME_KEYS" ]]; then
  echo ""
  echo "--- Runtime settings: no keys defined in ${ENV_EXAMPLE_FILE}, skipping ---"
elif [[ ! -f "$ENV_FILE" ]]; then
  echo ""
  echo "Warning: ${ENV_FILE} not found, skipping runtime settings" >&2
  echo "  Run: cp ${ENV_EXAMPLE_FILE} ${ENV_FILE}, fill in the values, then run this script again" >&2
else
  echo ""
  echo "--- Registering runtime settings (${ENV_FILE} → Environment: ${ENV}) ---"

  # Source .env.${ENV} in a subshell and register only the keys present in .env.example
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
        echo "  - ${name} (skipped: empty)"
      fi
    done
  )
fi

echo ""
echo "=== Setup for the ${ENV} environment is complete ==="
