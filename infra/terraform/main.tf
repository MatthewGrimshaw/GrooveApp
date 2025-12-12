# GrooveApp Infrastructure
# Main Terraform configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend configuration for state storage
  # Uncomment and configure for production use
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "stgrooveappstate"
  #   container_name       = "tfstate"
  #   key                  = "grooveapp.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# Data sources
data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

# Local variables
locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Application = "GrooveApp"
    }
  )

  # Database-specific naming
  db_server_name = "${var.naming_prefix}-${var.database_type}-${var.environment}"
  db_name        = "db-${var.naming_prefix}-${var.environment}"
}

# Database Module (conditional based on database_type)
module "database_sql" {
  count  = var.database_type == "sql" ? 1 : 0
  source = "./modules/database-sql"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  sql_server_name = local.db_server_name
  database_name   = local.db_name

  admin_user_id           = var.sql_admin_user_id
  admin_user_principal    = var.sql_admin_user_principal
  admin_user_display_name = var.sql_admin_user_display_name

  sku_name = var.sql_sku_name

  tags = local.common_tags
}

module "database_postgres" {
  count  = var.database_type == "postgres" ? 1 : 0
  source = "./modules/database-postgres"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  server_name   = local.db_server_name
  database_name = local.db_name

  admin_username = var.postgres_admin_username
  admin_password = var.postgres_admin_password

  sku_name = var.postgres_sku_name

  tags = local.common_tags
}

module "database_cosmos" {
  count  = var.database_type == "cosmos" ? 1 : 0
  source = "./modules/database-cosmos"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  account_name  = local.db_server_name
  database_name = local.db_name

  consistency_level = var.cosmos_consistency_level
  throughput        = var.cosmos_throughput

  tags = local.common_tags
}

# Container Registry
module "container_registry" {
  source = "./modules/container-registry"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  acr_name = "${var.naming_prefix}acr${var.environment}"
  sku      = var.acr_sku

  tags = local.common_tags
}

# App Service Plan
module "app_service_plan" {
  source = "./modules/app-service-plan"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  plan_name = "${var.naming_prefix}-plan-${var.environment}"

  os_type  = "Linux"
  sku_name = var.app_service_plan_sku

  tags = local.common_tags
}

# Entra ID Configuration
module "entra_id" {
  source = "./modules/entra-id"

  tenant_id           = var.tenant_id
  security_group_name = "${var.naming_prefix}-users-${var.environment}"

  api_app_name      = "${var.naming_prefix}-api-${var.environment}"
  frontend_app_name = "${var.naming_prefix}-frontend-${var.environment}"

  api_url      = "https://${var.naming_prefix}-api-${var.environment}.azurewebsites.net"
  frontend_url = "https://${var.naming_prefix}-frontend-${var.environment}.azurewebsites.net"

  initial_group_member_ids = var.initial_group_member_ids
}

# API Web App
module "api_web_app" {
  source = "./modules/web-app"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  app_name            = "${var.naming_prefix}-api-${var.environment}"
  app_service_plan_id = module.app_service_plan.id

  container_registry_url = module.container_registry.login_server
  container_image_name   = "grooveapp-api"
  container_image_tag    = var.api_image_tag

  acr_username = module.container_registry.admin_username
  acr_password = module.container_registry.admin_password

  app_settings = merge(
    var.api_app_settings,
    {
      WEBSITES_PORT = "8000"
      FRONTEND_URL  = "https://${var.naming_prefix}-frontend-${var.environment}.azurewebsites.net"
    },
    # Database-specific connection settings
    var.database_type == "sql" ? {
      SQL_SERVER   = module.database_sql[0].server_fqdn
      SQL_DATABASE = module.database_sql[0].database_name
      } : var.database_type == "postgres" ? {
      POSTGRES_HOST     = module.database_postgres[0].server_fqdn
      POSTGRES_DATABASE = module.database_postgres[0].database_name
      POSTGRES_USER     = var.postgres_admin_username
      POSTGRES_PASSWORD = var.postgres_admin_password
      } : var.database_type == "cosmos" ? {
      COSMOS_ENDPOINT = module.database_cosmos[0].endpoint
      COSMOS_KEY      = module.database_cosmos[0].primary_key
      COSMOS_DATABASE = module.database_cosmos[0].database_name
    } : {}
  )

  health_check_path = "/health"

  cors_allowed_origins = [
    "https://${var.naming_prefix}-frontend-${var.environment}.azurewebsites.net",
    "http://localhost:8080",
    "http://localhost:4200"
  ]

  # Easy Auth configuration
  auth_enabled        = var.enable_authentication
  auth_app_id         = module.entra_id.api_app_id
  auth_client_secret  = module.entra_id.api_client_secret
  auth_tenant_id      = var.tenant_id
  auth_excluded_paths = ["/health", "/docs", "/openapi.json"]

  tags = local.common_tags
}

# Frontend Web App
module "frontend_web_app" {
  source = "./modules/web-app"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  app_name            = "${var.naming_prefix}-frontend-${var.environment}"
  app_service_plan_id = module.app_service_plan.id

  container_registry_url = module.container_registry.login_server
  container_image_name   = "grooveapp-frontend"
  container_image_tag    = var.frontend_image_tag

  acr_username = module.container_registry.admin_username
  acr_password = module.container_registry.admin_password

  app_settings = merge(
    var.frontend_app_settings,
    {
      API_URL = "https://${var.naming_prefix}-api-${var.environment}.azurewebsites.net"
    }
  )

  health_check_path = "/"

  cors_allowed_origins = []

  # Easy Auth configuration
  auth_enabled        = var.enable_authentication
  auth_app_id         = module.entra_id.frontend_app_id
  auth_client_secret  = module.entra_id.frontend_client_secret
  auth_tenant_id      = var.tenant_id
  auth_excluded_paths = []

  tags = local.common_tags
}

# Grant API Web App managed identity access to database
resource "azurerm_role_assignment" "api_to_sql" {
  count = var.database_type == "sql" ? 1 : 0

  scope                = module.database_sql[0].server_id
  role_definition_name = "Contributor"
  principal_id         = module.api_web_app.identity_principal_id
}

resource "azurerm_role_assignment" "api_to_cosmos" {
  count = var.database_type == "cosmos" ? 1 : 0

  scope                = module.database_cosmos[0].account_id
  role_definition_name = "DocumentDB Account Contributor"
  principal_id         = module.api_web_app.identity_principal_id
}
