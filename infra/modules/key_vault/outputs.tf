output "name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.main.id
}

output "vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}
