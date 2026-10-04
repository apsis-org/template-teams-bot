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
  description = "Microsoft App ID for bot authentication"
  type        = string
}

variable "microsoft_app_type" {
  description = "Authentication type of the bot app"
  type        = string
  default     = "SingleTenant"
}

variable "microsoft_app_tenant_id" {
  description = "Tenant ID of the bot app (required for SingleTenant)"
  type        = string
}

variable "endpoint" {
  description = "Bot messaging endpoint URL"
  type        = string
}

variable "display_name" {
  description = "Display name of the bot. Shown where Teams falls back to the Azure resource name, such as the chat list."
  type        = string
}
