resource "random_string" "storage_suffix" {
  length  = 5
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "azurerm_storage_account" "main" {
  # Storage Account 名は 3-24 文字 / 小文字英数字のみ
  # "st"(2) + prefix(ハイフン除去、最大 17 文字に truncate) + ランダム(5) = 最大 24 文字
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

# Flex Consumption のデプロイ用 Blob コンテナ
resource "azurerm_storage_container" "deployment" {
  name               = "flex-deployment"
  storage_account_id = azurerm_storage_account.main.id
}

resource "azurerm_service_plan" "main" {
  name                = "asp-${var.prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "FC1" # Flex Consumption プラン
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

  # app_settings はデプロイワークフロー（.github/workflows/deploy-functions.yml の
  # "Apply runtime settings" ステップ）が .env.example に列挙されたキーを
  # `az functionapp config appsettings set` で差分更新する運用のため、
  # Terraform での drift 検出・上書きを無効化する。
  # ここで指定した app_settings は初回 apply 時のみ反映され、以降は Terraform 管理外となる。
  lifecycle {
    ignore_changes = [app_settings]
  }
}
