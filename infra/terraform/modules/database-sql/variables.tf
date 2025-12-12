variable "server_name" {
  description = "Name of the SQL Server"
  type        = string
}

variable "database_name" {
  description = "Name of the SQL Database"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "admin_user_id" {
  description = "Object ID of the Azure AD admin user"
  type        = string
}

variable "admin_user_principal" {
  description = "Principal name of the Azure AD admin user"
  type        = string
}

variable "sku_name" {
  description = "SKU name for the database (e.g., S0, S1, P1)"
  type        = string
  default     = "S0"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
