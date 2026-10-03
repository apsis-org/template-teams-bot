variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "microsoft_app_id" {
  description = "Bot 認証用 Microsoft App ID"
  type        = string
}

variable "microsoft_app_type" {
  description = "Bot アプリの認証タイプ"
  type        = string
  default     = "SingleTenant"
}

variable "microsoft_app_tenant_id" {
  description = "Bot アプリのテナント ID（SingleTenant 時に必須）"
  type        = string
}

variable "endpoint" {
  description = "Bot メッセージングエンドポイント URL"
  type        = string
}

variable "display_name" {
  description = "Bot の表示名。Teams の DM 一覧などで Azure リソース名にフォールバックされる箇所に表示される。"
  type        = string
}
