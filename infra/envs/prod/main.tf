terraform {
  required_version = ">= 1.7.0"

  # リモートステート管理（Azure Blob Storage）
  # 本番環境ではリモートステートを強く推奨します。
  # 事前に以下でストレージを作成してください:
  #   az group create --name rg-terraform-state --location japaneast
  #   az storage account create --name <YOUR_STORAGE_ACCOUNT> --resource-group rg-terraform-state --sku Standard_LRS
  #   az storage container create --name tfstate --account-name <YOUR_STORAGE_ACCOUNT>
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "<YOUR_STORAGE_ACCOUNT>"
  #   container_name       = "tfstate"
  #   key                  = "teams-bot/prod.tfstate"
  # }
}

provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.KeyVault",
    "Microsoft.Web",
    "Microsoft.Storage",
    "Microsoft.Insights",
    "Microsoft.OperationalInsights",
    "Microsoft.BotService",
  ]
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

variable "subscription_id" {
  description = "Azure サブスクリプション ID"
  type        = string
}

provider "azuread" {}

variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスに使用）"
  type        = string
}

variable "shared_key_vault_name" {
  description = "組織共通 Key Vault 名（make setup-secrets で参照するのみ）"
  type        = string
  default     = ""
}

module "main" {
  source = "../.."

  project_name = var.project_name
  environment  = "prod"
}
