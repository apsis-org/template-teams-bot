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

variable "application_insights_key" {
  type      = string
  sensitive = true
}

variable "application_insights_connection_string" {
  type      = string
  sensitive = true
}

variable "app_settings" {
  description = "Function App に追加するアプリケーション設定"
  type        = map(string)
  default     = {}
  sensitive   = true
}
