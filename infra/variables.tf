variable "project_name" {
  description = "Project name (used as the prefix of resource names)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name must consist of lowercase letters, digits, and hyphens only, and be 3 to 20 characters long."
  }
}

variable "environment" {
  description = "Environment name (stg / prod)"
  type        = string
  default     = "stg"

  validation {
    condition     = contains(["stg", "prod"], var.environment)
    error_message = "environment must be either stg or prod."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "japaneast"
}

variable "microsoft_app_type" {
  description = "Authentication type of the bot app (SingleTenant / UserAssignedMSI)"
  type        = string
  default     = "SingleTenant"

  validation {
    condition     = contains(["SingleTenant", "UserAssignedMSI"], var.microsoft_app_type)
    error_message = "microsoft_app_type must be either SingleTenant or UserAssignedMSI."
  }
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "shared_key_vault_name" {
  description = "Name of the organization-wide Key Vault holding the sp-github-actions credentials. Read by make setup-secrets only; not used to create Terraform resources."
  type        = string
  default     = ""
}
