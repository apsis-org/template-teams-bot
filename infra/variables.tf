variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスに使用）"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name は小文字英数字とハイフンのみ使用可能で、3〜20文字にしてください。"
  }
}

variable "environment" {
  description = "環境名（stg / prod）"
  type        = string
  default     = "stg"

  validation {
    condition     = contains(["stg", "prod"], var.environment)
    error_message = "environment は stg / prod のいずれかを指定してください。"
  }
}

variable "location" {
  description = "Azureリージョン"
  type        = string
  default     = "japaneast"
}

variable "microsoft_app_type" {
  description = "Bot アプリの認証タイプ（SingleTenant / UserAssignedMSI）"
  type        = string
  default     = "SingleTenant"

  validation {
    condition     = contains(["SingleTenant", "UserAssignedMSI"], var.microsoft_app_type)
    error_message = "microsoft_app_type は SingleTenant / UserAssignedMSI のいずれかを指定してください。"
  }
}

variable "tags" {
  description = "全リソースに付与する共通タグ"
  type        = map(string)
  default     = {}
}

variable "shared_key_vault_name" {
  description = "組織共通 Key Vault 名（sp-github-actions の認証情報を保管）。make setup-secrets で参照するのみで、Terraform リソースの作成には使用しない。"
  type        = string
  default     = ""
}
