# GrooveApp Infrastructure
# Main Terraform configuration

# Azure Naming Module
module "naming" {
  source = "./modules/naming"
  suffix = [var.naming_prefix, var.environment]
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

# Network Module
module "network" {
  source = "./modules/network"

  vnet_name                      = module.naming.virtual_network.name
  resource_group_name            = azurerm_resource_group.main.name
  location                       = var.location
  address_space                  = var.vnet_address_space
  app_service_subnet_name        = "${module.naming.subnet.name}-appservice"
  app_service_subnet_prefix      = var.app_service_subnet_prefix
  private_endpoint_subnet_name   = "${module.naming.subnet.name}-privateendpoints"
  private_endpoint_subnet_prefix = var.private_endpoint_subnet_prefix

  enable_sql_dns         = var.database_type == "sql"
  sql_dns_link_name      = "${module.naming.private_dns_zone.name}-sql-link"
  enable_postgres_dns    = var.database_type == "postgres"
  postgres_dns_link_name = "${module.naming.private_dns_zone.name}-postgres-link"

  tags = local.common_tags
}

# Database Module (conditional based on database_type)
module "database_sql" {
  count  = var.database_type == "sql" ? 1 : 0
  source = "./modules/database-sql"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  server_name   = module.naming.mssql_server.name_unique
  database_name = module.naming.mssql_database.name

  tenant_id            = var.tenant_id
  admin_user_id        = var.sql_admin_user_id
  admin_user_principal = var.sql_admin_user_principal

  sku_name = var.sql_sku_name

  # Private Endpoint Configuration
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id
  private_dns_zone_id        = var.enable_private_endpoints ? module.network.sql_private_dns_zone_id : ""

  # Deployment Access
  allow_deployment_access = var.allow_deployment_access
  deployment_ip_whitelist = var.deployment_ip_whitelist

  # Log Analytics
  log_analytics_workspace_id = module.log_analytics.workspace_id

  tags = local.common_tags

  depends_on = [
    module.network
  ]
}

module "database_postgres" {
  count  = var.database_type == "postgres" ? 1 : 0
  source = "./modules/database-postgres"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  server_name   = module.naming.postgresql_server.name_unique
  database_name = module.naming.postgresql_database.name

  admin_username = var.postgres_admin_username
  admin_password = var.postgres_admin_password

  sku_name = var.postgres_sku_name

  # Log Analytics
  log_analytics_workspace_id = module.log_analytics.workspace_id

  tags = local.common_tags
}

module "database_cosmos" {
  count  = var.database_type == "cosmos" ? 1 : 0
  source = "./modules/database-cosmos"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  account_name  = module.naming.cosmosdb_account.name_unique
  database_name = "${module.naming.mssql_database.name}-cosmos"

  consistency_level = var.cosmos_consistency_level
  # throughput        = var.cosmos_throughput

  # Log Analytics
  log_analytics_workspace_id = module.log_analytics.workspace_id

  tags = local.common_tags
}

# Log Analytics Workspace
module "log_analytics" {
  source = "./modules/log-analytics"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  workspace_name    = module.naming.log_analytics_workspace.name_unique
  app_insights_name = "${module.naming.application_insights.name}-grooveapp"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# Container Registry
module "container_registry" {
  source = "./modules/container-registry"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  registry_name              = module.naming.container_registry.name_unique
  sku                        = var.acr_sku
  log_analytics_workspace_id = module.log_analytics.workspace_id

  tags = local.common_tags
}

# App Service Plan
module "app_service_plan" {
  source = "./modules/app-service-plan"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  plan_name = module.naming.app_service_plan.name
  sku_name  = var.app_service_plan_sku

  tags = local.common_tags
}

# Entra ID Configuration (optional)
module "entra_id" {
  count  = var.enable_authentication ? 1 : 0
  source = "./modules/entra-id"

  tenant_id           = var.tenant_id
  app_name            = "appreg-${module.naming.app_service.name}"
  security_group_name = "${module.naming.resource_group.name}-users"
  owner_object_id     = data.azuread_client_config.current.object_id

  api_url                   = "https://${module.naming.app_service.name}-api.azurewebsites.net"
  frontend_url              = "https://${module.naming.app_service.name}-frontend.azurewebsites.net"
  supports_deployment_slots = can(regex("^(S[1-9]|P[1-9]V[2-3])", var.app_service_plan_sku))
}

# API Web App
module "api_web_app" {
  source = "./modules/web-app"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  app_name        = "${module.naming.app_service.name}-api"
  service_plan_id = module.app_service_plan.id

  acr_login_server = module.container_registry.login_server
  docker_image     = "grooveapp-api:${var.api_image_tag}"

  acr_username = module.container_registry.admin_username
  acr_password = module.container_registry.admin_password

  app_settings = merge(
    var.api_app_settings,
    {
      WEBSITES_PORT                              = "8000"
      FRONTEND_URL                               = "https://${module.naming.app_service.name}-frontend.azurewebsites.net"
      APPLICATIONINSIGHTS_CONNECTION_STRING      = module.log_analytics.app_insights_connection_string
      ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
      # Logging configuration
      LOG_LEVEL = var.log_level # OFF, ERROR, WARNING, INFO/ON, VERBOSE/DEBUG
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

  # CORS configuration for API
  cors_allowed_origins     = ["https://${module.naming.app_service.name}-frontend.azurewebsites.net"]
  cors_support_credentials = true

  # Easy Auth configuration
  enable_authentication     = var.enable_authentication
  supports_deployment_slots = can(regex("^(S[1-9]|P[1-9]V[2-3])", var.app_service_plan_sku))
  tenant_id                 = var.enable_authentication ? var.tenant_id : ""
  client_id                 = var.enable_authentication ? module.entra_id[0].api_app_id : ""
  client_secret             = var.enable_authentication ? module.entra_id[0].api_client_secret : ""
  unauthenticated_action    = "Return401"

  # VNet Integration for Private Endpoint access
  enable_vnet_integration    = var.enable_private_endpoints
  vnet_integration_subnet_id = module.network.app_service_subnet_id

  # Log Analytics
  log_analytics_workspace_id = module.log_analytics.workspace_id

  tags = local.common_tags
}

# Frontend Web App
module "frontend_web_app" {
  source = "./modules/web-app"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  app_name        = "${module.naming.app_service.name}-frontend"
  service_plan_id = module.app_service_plan.id

  acr_login_server = module.container_registry.login_server
  docker_image     = "grooveapp-frontend:${var.frontend_image_tag}"

  acr_username = module.container_registry.admin_username
  acr_password = module.container_registry.admin_password

  app_settings = merge(
    var.frontend_app_settings,
    {
      API_URL                                    = "https://${module.naming.app_service.name}-api.azurewebsites.net"
      APPLICATIONINSIGHTS_CONNECTION_STRING      = module.log_analytics.app_insights_connection_string
      ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
      # Logging configuration (same as backend)
      LOG_LEVEL = var.log_level # OFF, ERROR, WARNING, INFO, DEBUG
      # Nginx listens on port 8080 (not default 80)
      WEBSITES_PORT = "8080"
    }
  )

  health_check_path = "/"

  # Easy Auth configuration
  enable_authentication     = var.enable_authentication
  supports_deployment_slots = can(regex("^(S[1-9]|P[1-9]V[2-3])", var.app_service_plan_sku))
  tenant_id                 = var.enable_authentication ? var.tenant_id : ""
  client_id                 = var.enable_authentication ? module.entra_id[0].frontend_app_id : ""
  client_secret             = var.enable_authentication ? module.entra_id[0].frontend_client_secret : ""

  # VNet Integration for private endpoint access
  enable_vnet_integration    = var.enable_private_endpoints
  vnet_integration_subnet_id = module.network.app_service_subnet_id

  # Log Analytics
  log_analytics_workspace_id = module.log_analytics.workspace_id

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

# Grant API Web App managed identity access to pull from ACR
resource "azurerm_role_assignment" "api_to_acr" {
  scope                = module.container_registry.registry_id
  role_definition_name = "AcrPull"
  principal_id         = module.api_web_app.identity_principal_id
}

# Grant Frontend Web App managed identity access to pull from ACR
resource "azurerm_role_assignment" "frontend_to_acr" {
  scope                = module.container_registry.registry_id
  role_definition_name = "AcrPull"
  principal_id         = module.frontend_web_app.identity_principal_id
}
