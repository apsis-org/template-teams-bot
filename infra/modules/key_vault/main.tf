data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "kv-${replace(var.prefix, "-", "")}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags
}

# Terraform 実行者にフルアクセスを付与
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

# Function App のマネージド ID に読み取り権限を付与
resource "azurerm_key_vault_access_policy" "readers" {
  count        = length(var.access_principal_ids)
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.access_principal_ids[count.index]

  secret_permissions = ["Get", "List"]
}

# シークレットを Key Vault に格納
resource "azurerm_key_vault_secret" "secrets" {
  count        = length(var.secret_names)
  name         = var.secret_names[count.index]
  value        = var.secret_values[count.index]
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.terraform]
}
