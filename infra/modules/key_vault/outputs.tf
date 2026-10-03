output "name" {
  description = "Key Vault 名"
  value       = azurerm_key_vault.main.name
}

output "id" {
  description = "Key Vault リソース ID"
  value       = azurerm_key_vault.main.id
}

output "vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}
