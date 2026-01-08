# Output values

# Resource Group
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}


# Database Outputs (conditional based on type)
output "database_type" {
  description = "Type of database deployed"
  value       = var.database_type
}

output "database_server_fqdn" {
  description = "Fully qualified domain name of the database server"
  value = var.database_type == "sql" ? (
    length(module.database_sql) > 0 ? module.database_sql[0].server_fqdn : null
    ) : var.database_type == "postgres" ? (
    length(module.database_postgres) > 0 ? module.database_postgres[0].server_fqdn : null
    ) : var.database_type == "cosmos" ? (
    length(module.database_cosmos) > 0 ? module.database_cosmos[0].endpoint : null
  ) : null
}

output "database_name" {
  description = "Name of the database"
  value = var.database_type == "sql" ? (
    length(module.database_sql) > 0 ? module.database_sql[0].database_name : null
    ) : var.database_type == "postgres" ? (
    length(module.database_postgres) > 0 ? module.database_postgres[0].database_name : null
    ) : var.database_type == "cosmos" ? (
    length(module.database_cosmos) > 0 ? module.database_cosmos[0].database_name : null
  ) : null
}


# Container Registry
output "acr_login_server" {
  description = "Login server URL for Azure Container Registry"
  value       = module.container_registry.login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.container_registry.name
}

# App Service Plan
output "app_service_plan_id" {
  description = "ID of the App Service Plan"
  value       = module.app_service_plan.id
}

output "app_service_plan_name" {
  description = "Name of the App Service Plan"
  value       = module.app_service_plan.name
}

# API Web App
output "api_url" {
  description = "URL of the API Web App"
  value       = "https://${module.api_web_app.default_hostname}"
}

output "api_app_name" {
  description = "Name of the API Web App"
  value       = module.api_web_app.name
}

output "api_identity_principal_id" {
  description = "Principal ID of the API Web App managed identity"
  value       = module.api_web_app.identity_principal_id
}

# Frontend Web App
output "frontend_url" {
  description = "URL of the Frontend Web App"
  value       = "https://${module.frontend_web_app.default_hostname}"
}

output "frontend_app_name" {
  description = "Name of the Frontend Web App"
  value       = module.frontend_web_app.name
}

output "frontend_identity_principal_id" {
  description = "Principal ID of the Frontend Web App managed identity"
  value       = module.frontend_web_app.identity_principal_id
}

# Entra ID
output "security_group_id" {
  description = "Object ID of the security group"
  value       = var.enable_authentication ? module.entra_id[0].security_group_id : null
}

output "security_group_name" {
  description = "Name of the security group"
  value       = var.enable_authentication ? module.entra_id[0].security_group_name : null
}

output "api_app_registration_id" {
  description = "Application (client) ID of the API app registration"
  value       = var.enable_authentication ? module.entra_id[0].api_app_id : null
  sensitive   = true
}

output "frontend_app_registration_id" {
  description = "Application (client) ID of the Frontend app registration"
  value       = var.enable_authentication ? module.entra_id[0].frontend_app_id : null
  sensitive   = true
}

# Log Analytics and Monitoring
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.log_analytics.workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = module.log_analytics.workspace_name
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = module.log_analytics.app_insights_instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = module.log_analytics.app_insights_connection_string
  sensitive   = true
}

# Summary
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    environment        = var.environment
    resource_group     = azurerm_resource_group.main.name
    location           = var.location
    database_type      = var.database_type
    api_url            = "https://${module.api_web_app.default_hostname}"
    api_docs           = "https://${module.api_web_app.default_hostname}/docs"
    frontend_url       = "https://${module.frontend_web_app.default_hostname}"
    security_group     = var.enable_authentication ? module.entra_id[0].security_group_name : "N/A - Authentication Disabled"
    container_registry = module.container_registry.login_server
    log_analytics      = module.log_analytics.workspace_name
  }
}

