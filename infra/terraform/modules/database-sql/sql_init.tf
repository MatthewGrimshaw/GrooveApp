# SQL Database Initialization Script Resource
# This uses Azure Container Instances to run SQL scripts with private endpoint access

resource "azurerm_user_assigned_identity" "sql_init" {
  count = var.enable_sql_initialization ? 1 : 0

  name                = "${var.server_name}-init-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

# Grant the managed identity SQL admin access
resource "azurerm_mssql_server_extended_auditing_policy" "sql_init_access" {
  count = var.enable_sql_initialization ? 1 : 0

  server_id = azurerm_mssql_server.main.id
}

# Output for script execution
output "init_identity_client_id" {
  description = "Client ID of the initialization managed identity"
  value       = var.enable_sql_initialization ? azurerm_user_assigned_identity.sql_init[0].client_id : ""
}

output "init_identity_principal_id" {
  description = "Principal ID of the initialization managed identity"
  value       = var.enable_sql_initialization ? azurerm_user_assigned_identity.sql_init[0].principal_id : ""
}
