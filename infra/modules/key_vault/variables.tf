variable "resource_group_name" {
  description = "リソースグループ名"
  type        = string
}

variable "location" {
  description = "Azure リージョン"
  type        = string
}

variable "prefix" {
  description = "リソース名のプレフィックス"
  type        = string
}

variable "tags" {
  description = "リソースに付与するタグ"
  type        = map(string)
  default     = {}
}

variable "secret_names" {
  description = "Key Vault に格納するシークレットのキー名リスト"
  type        = list(string)
}

variable "secret_values" {
  description = "Key Vault に格納するシークレットの値リスト（secret_names と同順）"
  type        = list(string)
  sensitive   = true
}

variable "access_principal_ids" {
  description = "シークレットの読み取り権限を付与するプリンシパル ID"
  type        = list(string)
  default     = []
}
