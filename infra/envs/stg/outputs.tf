output "resource_group_name" {
  description = "Resource group name"
  value       = module.main.resource_group_name
}

output "function_app_name" {
  description = "Function App name"
  value       = module.main.function_app_name
}

output "function_app_hostname" {
  description = "Function App hostname"
  value       = module.main.function_app_hostname
}

output "bot_messaging_endpoint" {
  description = "Bot Framework messaging endpoint"
  value       = module.main.bot_messaging_endpoint
}

output "microsoft_app_id" {
  description = "Microsoft App ID for bot authentication"
  value       = module.main.microsoft_app_id
}

output "microsoft_app_password" {
  description = "Microsoft App Password for bot authentication (sensitive)"
  value       = module.main.microsoft_app_password
  sensitive   = true
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = module.main.key_vault_name
}

output "bot_service_name" {
  description = "Azure Bot Service name"
  value       = module.main.bot_service_name
}
