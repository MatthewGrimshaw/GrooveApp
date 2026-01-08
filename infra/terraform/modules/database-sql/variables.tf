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

variable "enable_private_endpoint" {
  description = "Enable private endpoint for SQL Server"
  type        = bool
  default     = true
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
  default     = ""
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for SQL Server"
  type        = string
  default     = ""
}

variable "allow_deployment_access" {
  description = "Allow public access for deployments"
  type        = bool
  default     = false
}

variable "deployment_ip_whitelist" {
  description = "List of IP addresses to whitelist for deployments"
  type        = list(string)
  default     = []
}

variable "api_managed_identity_principal_id" {
  description = "Principal ID of the API app's managed identity"
  type        = string
  default     = ""
}

variable "enable_sql_initialization" {
  description = "Enable SQL initialization resources"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for diagnostic settings"
  type        = string
}
