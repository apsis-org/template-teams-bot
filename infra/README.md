# Infrastructure Setup Guide

**English** | [日本語](README.ja.md)

This document describes the infrastructure setup that is performed **once**, when you create a new project from this template.
Other developers should start from the "Local development" section of the root [README.md](../README.md).

## Directory layout

Each environment has its own directory, so their state files are fully isolated.

```
infra/
  envs/
    terraform.tfvars.example      ← set project_name here (shared by stg/prod)
    terraform.tfvars              ← created by copying the file above (gitignored)
    stg/
      main.tf                     ← root module for stg
      terraform.tfvars → ../terraform.tfvars (symbolic link)
    prod/
      main.tf                     ← root module for prod
      terraform.tfvars → ../terraform.tfvars (symbolic link)
  main.tf                         ← shared module (never run directly)
```

## Preparation: organization-wide setup (once per organization)

Prepare a service principal for deploying from GitHub Actions to Azure, and an organization-wide Key Vault that stores its credentials.
This is done **once per organization**. If you create a second bot from this template, skip it (just confirm the Key Vault name in step ④).

In the Azure Portal (requires the Owner role on the subscription):

**① Create the service principal**

1. Microsoft Entra ID → App registrations → New registration
2. Name: `sp-github-actions`, then Register
3. Certificates & secrets → New client secret → Add
4. Copy the displayed **value** (it is shown only once)

**② Assign a role**

1. Subscription → Access control (IAM) → Add role assignment
2. Role: **Contributor**, Members: select `sp-github-actions`
3. Save

**③ Create the organization-wide Key Vault**

1. Create a resource group `rg-shared`
2. Create a Key Vault (for example `kv-<org>-gh-actions`), region `Japan East` (or your preferred region), permission model: Azure RBAC
3. Register the secrets:
   - `sp-github-actions-client-id`: the client ID
   - `sp-github-actions-client-secret`: the client secret
4. Grant every developer the **Key Vault Secrets Officer** role

**④ Note the Key Vault name**

The Key Vault name from ③ goes into `shared_key_vault_name` in `infra/envs/terraform.tfvars` in "2. Set project_name" below.

```hcl
shared_key_vault_name = "kv-<org>-gh-actions"
```

## Building the infrastructure with Terraform

Running `terraform plan` / `terraform apply` in each environment directory creates the following resources **independently per environment**.

| Resource         | stg                     | prod                     |
| ---------------- | ----------------------- | ------------------------ |
| Resource Group   | `rg-<project>-stg`      | `rg-<project>-prod`      |
| Function App     | `func-<project>-stg`    | `func-<project>-prod`    |
| Bot Service      | `bot-<project>-stg`     | `bot-<project>-prod`     |
| Key Vault        | `kv-<project>-stg`      | `kv-<project>-prod`      |
| App Registration | `app-<project>-stg-bot` | `app-<project>-prod-bot` |

The bot credentials (`MicrosoftAppId` / `MicrosoftAppPassword`) are bound one-to-one to a messaging endpoint, so each environment and project needs its own.
`terraform apply` generates them and stores them in Key Vault automatically.

### Estimated cost

| Resource                  | Plan                   | Price                                        |
| ------------------------- | ---------------------- | -------------------------------------------- |
| Function App              | Flex Consumption (FC1) | Free up to 250k executions + 100,000 GB-s/mo |
| Bot Service               | F0                     | Free                                         |
| Storage Account           | Standard LRS           | A few cents per month                        |
| Key Vault                 | Standard               | About $0.03 per 10k operations (negligible)  |
| Application Insights      | —                      | Free up to 5 GB/month                        |
| Log Analytics             | —                      | Free up to 5 GB/month                        |
| Azure AD App Registration | —                      | Free                                         |

For an internal bot with light traffic the monthly cost is effectively zero (a few cents of storage).

### 1. Sign in to Azure

```bash
az login
```

### 2. Set project_name

```bash
cp infra/envs/terraform.tfvars.example infra/envs/terraform.tfvars
```

Open `infra/envs/terraform.tfvars` and set the following (shared by stg and prod).

- `project_name`: **always change this to a value unique to your project**
- `subscription_id`: the Azure subscription to deploy to
- `shared_key_vault_name`: the organization-wide Key Vault created in [Preparation](#preparation-organization-wide-setup-once-per-organization)

> ⚠️ **Warning**: If you run `terraform apply` with the default `myteamsbot`, it is baked into the resource names and is hard to change later (a deleted Key Vault cannot be recreated under the same name during the soft-delete period, Storage Account names are globally unique, and so on). Always change it first.

Constraints on `project_name`:

- Lowercase letters, digits, and hyphens only, 3 to 20 characters
- Used as the prefix of Azure resource names (`rg-<project_name>-<env>` and so on)
- Examples: `banking-info-bot`, `payroll-bot`

### 3. Build the stg environment

Build only stg first. Do not create prod yet; it is rolled out after stg has been verified (see below).

```bash
cd infra/envs/stg
terraform init
terraform plan
terraform apply
```

`terraform apply` creates the Azure resources and, at the same time, stores the bot credentials (`MicrosoftAppId` / `MicrosoftAppPassword`) in Key Vault.

> **Note:** `terraform destroy` deletes the Function App as well. After running `terraform apply` again, redeploy the code from GitHub Actions.

## GitHub Actions deployment settings (stg)

Run this from the repository root after `terraform apply` has completed. `az login` and `gh auth login` must be done.

```bash
cd ../../..    # back to the repository root from infra/envs/stg
make setup-secrets
# choose "stg" at the prompt
```

The script fetches the credentials from Key Vault and registers the following in GitHub (Variables are bound to the GitHub Environment `stg`).

| Kind     | Name                      | Content                                                             |
| -------- | ------------------------- | ------------------------------------------------------------------- |
| Secret   | `AZURE_CREDENTIALS`       | Service principal credentials (repository-wide)                     |
| Variable | `AZURE_FUNCTION_APP_NAME` | Function App name (e.g. `func-sample-bot-stg`)                      |
| Variable | `AZURE_RESOURCE_GROUP`    | Resource group name (e.g. `rg-sample-bot-stg`)                      |
| Variable | `MICROSOFT_APP_ID`        | App ID for bot authentication (used to build the Teams app package) |

In addition, if `.env.example` defines keys and `.env.stg` exists, their values are registered as Secrets in the GitHub Environment `stg` as well (runtime settings such as external API keys the bot uses; see "Adding runtime settings (environment variables)" in the root [README.md](../README.md)).

## Verifying stg

Once the above is done, follow "Deployment" in the root [README.md](../README.md) to deploy the code to stg and confirm the bot actually responds in Teams.

- Run the GitHub Actions deployment with `stg` as the target
- Upload the Teams app package (`teams-app-stg-*`) in the Teams admin center
- Send the bot a message in Teams and confirm it responds as expected

## Rolling out prod

> ⚠️ **Only after everything has been verified in stg.** If you find a problem in stg, fix, redeploy, and re-verify there before touching prod.

prod repeats the same steps as stg.

### 1. Build the prod environment

```bash
cd infra/envs/prod
terraform init
terraform plan
terraform apply
```

stg and prod have separate state, so they do not affect each other.

### 2. GitHub Actions deployment settings (prod)

```bash
cd ../../..    # back to the repository root from infra/envs/prod
make setup-secrets
# choose "prod" at the prompt
```

The Variables are registered in the GitHub Environment `prod`.

### 3. Deploy to prod and verify

Follow "Deployment" in the root [README.md](../README.md): run the deployment with `prod` as the target, upload the Teams app package (`teams-app-prod-*`) in the Teams admin center, and verify.

## Reference

The commands below are not needed in the normal deployment flow (GitHub Actions → Azure Functions → Teams). They are for checking values locally or for special debugging.

### Reading Terraform outputs

To look up the deployed URL or IDs locally, run `terraform output` in the environment directory (`make setup-secrets` reads these from the Terraform state itself, so this is not required for deployment).

```bash
cd infra/envs/stg   # or infra/envs/prod
terraform output bot_messaging_endpoint
terraform output microsoft_app_id
terraform output key_vault_name

# sensitive values (e.g. the app password) need -raw
terraform output -raw microsoft_app_password
```

### Fetching Bot Framework credentials for local runs

Only needed if you run `pnpm start` locally and want Azure Bot Service to reach your machine through a tunnel such as ngrok. Not needed if Agents Playground is enough or you only deploy via GitHub Actions.

Updates `MicrosoftAppId` / `MicrosoftAppPassword` / `MicrosoftAppTenantId` / `MicrosoftAppType` in `local.settings.json` with the values from Key Vault (other existing keys are preserved).

```bash
make generate-local-settings
```
