output "name" {
  value = azurerm_function_app_flex_consumption.main.name
}

output "default_hostname" {
  value = azurerm_function_app_flex_consumption.main.default_hostname
}

output "id" {
  value = azurerm_function_app_flex_consumption.main.id
}

output "principal_id" {
  description = "Function App のマネージド ID（Key Vault 連携などで使用）"
  value       = azurerm_function_app_flex_consumption.main.identity[0].principal_id
}
