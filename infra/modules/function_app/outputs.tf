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
  description = "Managed identity of the Function App (used for Key Vault access etc.)"
  value       = azurerm_function_app_flex_consumption.main.identity[0].principal_id
}
