resource "random_string" "storage_suffix" {
  length  = 5
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  # Storage Account names are 3-24 characters, lowercase alphanumeric only
  # "st"(2) + prefix (hyphens removed, truncated to 17 chars) + random(5) = at most 24 chars
  name                     = "st${substr(replace(var.prefix, "-", ""), 0, 17)}${random_string.storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

# Blob container for Flex Consumption deployments
resource "azurerm_storage_container" "deployment" {
  name               = "flex-deployment"
  storage_account_id = azurerm_storage_account.main.id
}

resource "azurerm_service_plan" "main" {
  name                = "asp-${var.prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "FC1" # Flex Consumption plan
  tags                = var.tags
}

resource "azurerm_function_app_flex_consumption" "main" {
  name                = "func-${var.prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.deployment.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.main.primary_access_key

  runtime_name    = "node"
  runtime_version = "24"

  instance_memory_in_mb  = 2048
  maximum_instance_count = 100

  identity {
    type = "SystemAssigned"
  }

  site_config {}

  app_settings = merge(
    {
      APPINSIGHTS_INSTRUMENTATIONKEY        = var.application_insights_key
      APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
    },
    var.app_settings
  )

  # app_settings are updated incrementally by the deployment workflow
  # (the "Apply runtime settings" step in .github/workflows/deploy-functions.yml runs
  # `az functionapp config appsettings set` for the keys listed in .env.example),
  # so drift detection / overwriting by Terraform is disabled.
  # The app_settings given here are applied on the first apply only and are unmanaged afterwards.
  lifecycle {
    ignore_changes = [app_settings]
  }
}
