output "resource_group_name" {
  description = "リソースグループ名"
  value       = azurerm_resource_group.main.name
}

output "function_app_name" {
  description = "Function App 名"
  value       = module.function_app.name
}

output "function_app_hostname" {
  description = "Function App のホスト名"
  value       = module.function_app.default_hostname
}

output "bot_messaging_endpoint" {
  description = "Bot Framework メッセージングエンドポイント"
  value       = "https://${module.function_app.default_hostname}/api/messages"
}

output "microsoft_app_id" {
  description = "Bot 認証用 Microsoft App ID"
  value       = azuread_application.bot.client_id
  sensitive   = false
}

output "microsoft_app_password" {
  description = "Bot 認証用 Microsoft App Password（機密情報）"
  value       = azuread_application_password.bot.value
  sensitive   = true
}

output "key_vault_name" {
  description = "Key Vault 名"
  value       = module.key_vault.name
}

output "bot_service_name" {
  description = "Azure Bot Service 名"
  value       = module.bot_service.name
}
