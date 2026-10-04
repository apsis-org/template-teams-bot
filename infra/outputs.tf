output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "function_app_name" {
  description = "Function App name"
  value       = module.function_app.name
}

output "function_app_hostname" {
  description = "Function App hostname"
  value       = module.function_app.default_hostname
}

output "bot_messaging_endpoint" {
  description = "Bot Framework messaging endpoint"
  value       = "https://${module.function_app.default_hostname}/api/messages"
}

output "microsoft_app_id" {
  description = "Microsoft App ID for bot authentication"
  value       = azuread_application.bot.client_id
  sensitive   = false
}

output "microsoft_app_password" {
  description = "Microsoft App Password for bot authentication (sensitive)"
  value       = azuread_application_password.bot.value
  sensitive   = true
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = module.key_vault.name
}

output "bot_service_name" {
  description = "Azure Bot Service name"
  value       = module.bot_service.name
}
