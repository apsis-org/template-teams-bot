locals {
  # Common prefix for resource names (e.g. teams-bot-stg)
  prefix = "${var.project_name}-${var.environment}"

  # Read the Teams app manifest as the single source of truth and derive the
  # Azure Bot Service display_name from it (avoids hardcoding the app-specific name in tf files).
  # name.short in manifest.json contains the `__ENV_SUFFIX__` placeholder, which is replaced
  # with the same rule as build-teams-app.yml (empty for prod, " [env]" otherwise).
  teams_manifest   = jsondecode(file("${path.module}/../appPackage/manifest.json"))
  env_suffix       = var.environment == "prod" ? "" : " [${var.environment}]"
  bot_display_name = replace(local.teams_manifest.name.short, "__ENV_SUFFIX__", local.env_suffix)

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# -------------------------------------------------------------------
# Resource Group
# -------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.prefix}"
  location = var.location
  tags     = local.common_tags
}

# -------------------------------------------------------------------
# Azure AD App Registration (bot authentication)
# -------------------------------------------------------------------
data "azuread_client_config" "current" {}

resource "azuread_application" "bot" {
  display_name = "app-${local.prefix}-bot"
  owners       = [data.azuread_client_config.current.object_id]

  api {
    requested_access_token_version = 2
  }
}

resource "azuread_service_principal" "bot" {
  client_id = azuread_application.bot.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "bot" {
  application_id = azuread_application.bot.id
  display_name   = "bot-secret"
  # Effectively non-expiring as the template default.
  # If your organization has a secret rotation policy, shorten this and
  # regenerate with terraform apply before it expires.
  # The regenerated value is written to Key Vault automatically, but the Function App's
  # app_settings are set to ignore_changes in modules/function_app, so MicrosoftAppPassword
  # must be updated there manually.
  end_date = "2099-01-01T00:00:00Z"
}

# -------------------------------------------------------------------
# Modules
# -------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix              = local.prefix
  tags                = local.common_tags
}

module "function_app" {
  source = "./modules/function_app"

  resource_group_name                    = azurerm_resource_group.main.name
  location                               = azurerm_resource_group.main.location
  prefix                                 = local.prefix
  tags                                   = local.common_tags
  application_insights_key               = module.monitoring.instrumentation_key
  application_insights_connection_string = module.monitoring.connection_string

  app_settings = {
    MicrosoftAppId       = azuread_application.bot.client_id
    MicrosoftAppPassword = azuread_application_password.bot.value
    MicrosoftAppType     = var.microsoft_app_type
    MicrosoftAppTenantId = data.azuread_client_config.current.tenant_id
  }
}

module "key_vault" {
  source = "./modules/key_vault"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  prefix              = local.prefix
  tags                = local.common_tags

  secret_names  = ["MicrosoftAppId", "MicrosoftAppPassword"]
  secret_values = [azuread_application.bot.client_id, azuread_application_password.bot.value]

  access_principal_ids = [module.function_app.principal_id]
}

module "bot_service" {
  source = "./modules/bot_service"

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  prefix                  = local.prefix
  tags                    = local.common_tags
  display_name            = local.bot_display_name
  microsoft_app_id        = azuread_application.bot.client_id
  microsoft_app_type      = var.microsoft_app_type
  microsoft_app_tenant_id = data.azuread_client_config.current.tenant_id
  endpoint                = "https://${module.function_app.default_hostname}/api/messages"
}
