output "resource_group_name" {
  description = "リソースグループ名"
  value       = module.main.resource_group_name
}

output "function_app_name" {
  description = "Function App 名"
  value       = module.main.function_app_name
}

output "function_app_hostname" {
  description = "Function App のホスト名"
  value       = module.main.function_app_hostname
}

output "bot_messaging_endpoint" {
  description = "Bot Framework メッセージングエンドポイント"
  value       = module.main.bot_messaging_endpoint
}

output "microsoft_app_id" {
  description = "Bot 認証用 Microsoft App ID"
  value       = module.main.microsoft_app_id
}

output "microsoft_app_password" {
  description = "Bot 認証用 Microsoft App Password（機密情報）"
  value       = module.main.microsoft_app_password
  sensitive   = true
}

output "key_vault_name" {
  description = "Key Vault 名"
  value       = module.main.key_vault_name
}

output "bot_service_name" {
  description = "Azure Bot Service 名"
  value       = module.main.bot_service_name
}
