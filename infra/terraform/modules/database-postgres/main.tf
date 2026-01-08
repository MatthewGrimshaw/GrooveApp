# Azure PostgreSQL Flexible Server Module

resource "azurerm_postgresql_flexible_server" "main" {
  name                = var.server_name
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "16"

  administrator_login    = var.admin_username
  administrator_password = var.admin_password

  storage_mb = 32768
  sku_name   = var.sku_name
  zone       = "1"

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Firewall rule to allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Configuration for connection pooling
resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "100"
}

# Diagnostic Settings for PostgreSQL Server
resource "azurerm_monitor_diagnostic_setting" "postgres_server" {
  name                       = "${var.server_name}-diagnostics"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # PostgreSQL logs
  enabled_log {
    category = "PostgreSQLLogs"
  }

  # Metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
