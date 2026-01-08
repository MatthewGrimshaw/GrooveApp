# Core Infrastructure Variables

variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "grooveapp"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# Network Configuration

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "app_service_subnet_prefix" {
  description = "Address prefix for the App Service subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "private_endpoint_subnet_prefix" {
  description = "Address prefix for the private endpoint subnet"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for database and other services"
  type        = bool
  default     = true
}

variable "allow_deployment_access" {
  description = "Allow public access for deployments (GitHub Actions)"
  type        = bool
  default     = false
}

variable "deployment_ip_whitelist" {
  description = "List of IP addresses to allow for deployments"
  type        = list(string)
  default     = []
}

# Database Configuration

variable "database_type" {
  description = "Type of database to deploy (sql, postgres, cosmos)"
  type        = string
  validation {
    condition     = contains(["sql", "postgres", "cosmos"], var.database_type)
    error_message = "Database type must be sql, postgres, or cosmos."
  }
}

# Azure SQL Database Variables
variable "sql_admin_user_id" {
  description = "Object ID of the Azure AD admin user for SQL Server"
  type        = string
  default     = ""
}

variable "sql_admin_user_principal" {
  description = "User Principal Name of the Azure AD admin for SQL Server"
  type        = string
  default     = ""
}

variable "sql_admin_user_display_name" {
  description = "Display name of the Azure AD admin for SQL Server"
  type        = string
  default     = ""
}

variable "sql_sku_name" {
  description = "SKU name for Azure SQL Database"
  type        = string
  default     = "S0"
}

# PostgreSQL Variables
variable "postgres_admin_username" {
  description = "Administrator username for PostgreSQL"
  type        = string
  default     = "psqladmin"
  sensitive   = true
}

variable "postgres_admin_password" {
  description = "Administrator password for PostgreSQL"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_sku_name" {
  description = "SKU name for PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
}

# Cosmos DB Variables
variable "cosmos_consistency_level" {
  description = "Consistency level for Cosmos DB"
  type        = string
  default     = "Session"
  validation {
    condition     = contains(["Eventual", "ConsistentPrefix", "Session", "BoundedStaleness", "Strong"], var.cosmos_consistency_level)
    error_message = "Invalid Cosmos DB consistency level."
  }
}

variable "cosmos_throughput" {
  description = "Throughput (RU/s) for Cosmos DB"
  type        = number
  default     = 400
}

# Container Registry
variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

# App Service
variable "app_service_plan_sku" {
  description = "SKU for App Service Plan"
  type        = string
  default     = "S1"
}

variable "api_image_tag" {
  description = "Docker image tag for API"
  type        = string
  default     = "latest"
}

variable "frontend_image_tag" {
  description = "Docker image tag for Frontend"
  type        = string
  default     = "latest"
}

variable "api_app_settings" {
  description = "Additional app settings for API Web App"
  type        = map(string)
  default     = {}
}

variable "frontend_app_settings" {
  description = "Additional app settings for Frontend Web App"
  type        = map(string)
  default     = {}
}

# Authentication
variable "enable_authentication" {
  description = "Enable Easy Auth (Entra ID) on web apps"
  type        = bool
  default     = true
}

variable "initial_group_member_ids" {
  description = "List of user object IDs to add to the security group"
  type        = list(string)
  default     = []
}

# Logging and Monitoring
variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics workspace"
  type        = number
  default     = 30
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 30 and 730 days."
  }
}

variable "log_level" {
  description = "Application log level (OFF, ERROR, WARNING, INFO, ON, VERBOSE, DEBUG)"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["OFF", "ERROR", "WARNING", "INFO", "ON", "VERBOSE", "DEBUG"], var.log_level)
    error_message = "Log level must be one of: OFF, ERROR, WARNING, INFO, ON, VERBOSE, DEBUG."
  }
}
