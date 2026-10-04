variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags applied to the resources"
  type        = map(string)
  default     = {}
}

variable "secret_names" {
  description = "Names of the secrets to store in Key Vault"
  type        = list(string)
}

variable "secret_values" {
  description = "Values of the secrets to store in Key Vault (same order as secret_names)"
  type        = list(string)
  sensitive   = true
}

variable "access_principal_ids" {
  description = "Principal IDs granted read access to the secrets"
  type        = list(string)
  default     = []
}
