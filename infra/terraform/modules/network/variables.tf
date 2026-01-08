# Network Module Variables

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "app_service_subnet_name" {
  description = "Name of the App Service subnet"
  type        = string
}

variable "app_service_subnet_prefix" {
  description = "Address prefix for App Service subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "private_endpoint_subnet_name" {
  description = "Name of the Private Endpoint subnet"
  type        = string
}

variable "private_endpoint_subnet_prefix" {
  description = "Address prefix for Private Endpoint subnet"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "enable_sql_dns" {
  description = "Enable Private DNS zone for SQL Server"
  type        = bool
  default     = false
}

variable "sql_dns_link_name" {
  description = "Name of the SQL DNS zone virtual network link"
  type        = string
  default     = ""
}

variable "enable_postgres_dns" {
  description = "Enable Private DNS zone for PostgreSQL"
  type        = bool
  default     = false
}

variable "postgres_dns_link_name" {
  description = "Name of the PostgreSQL DNS zone virtual network link"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
