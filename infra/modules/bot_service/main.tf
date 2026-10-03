resource "azurerm_bot_service_azure_bot" "main" {
  name                    = "bot-${var.prefix}"
  display_name            = var.display_name
  resource_group_name     = var.resource_group_name
  location                = "global"
  microsoft_app_id        = var.microsoft_app_id
  microsoft_app_type      = var.microsoft_app_type
  microsoft_app_tenant_id = var.microsoft_app_tenant_id
  sku                     = "F0" # 無料プラン（本番は S1 を推奨）
  endpoint                = var.endpoint
  tags                    = var.tags

  # Teams チャンネルは別途 azurerm_bot_channel_ms_teams で有効化
}

resource "azurerm_bot_channel_ms_teams" "main" {
  bot_name            = azurerm_bot_service_azure_bot.main.name
  location            = "global"
  resource_group_name = var.resource_group_name
  calling_web_hook    = null
  calling_enabled     = false
}
