locals {
  # リソース名の共通プレフィックス（例: teams-bot-stg）
  prefix = "${var.project_name}-${var.environment}"

  # Teams アプリ manifest を Single Source of Truth として読み込み、
  # Azure Bot Service の display_name もここから導出する（tf ファイルのアプリ固有名をハードコード回避）。
  # manifest.json の name.short には `__ENV_SUFFIX__` プレースホルダーが含まれており、
  # build-teams-app.yml と同じ規則（prod は空、それ以外は " [env]"）で置換する。
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
# Azure AD App Registration（Bot 認証用）
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
  # テンプレートの既定値として実質無期限にしている。
  # 組織のシークレットローテーション方針がある場合は短い期限に変更し、
  # 期限前に terraform apply で再生成する運用にすること。
  # 再生成した値は Key Vault には自動反映されるが、Function App の app_settings は
  # modules/function_app で ignore_changes にしているため、MicrosoftAppPassword の手動更新が必要。
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
