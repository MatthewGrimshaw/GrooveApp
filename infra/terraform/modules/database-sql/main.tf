# Azure SQL Database Module

resource "azurerm_mssql_server" "main" {
  name                          = var.server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = var.allow_deployment_access

  azuread_administrator {
    login_username              = var.admin_user_principal
    object_id                   = var.admin_user_id
    tenant_id                   = var.tenant_id
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_mssql_database" "main" {
  name           = var.database_name
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  sku_name       = var.sku_name
  zone_redundant = false

  tags = var.tags
}

# Firewall rule to allow Azure services (only when public access is enabled)
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  count = var.allow_deployment_access ? 1 : 0

  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Firewall rules for deployment access (GitHub Actions)
resource "azurerm_mssql_firewall_rule" "deployment_access" {
  for_each = var.allow_deployment_access ? toset(["0"]) : toset([])

  name             = "AllowDeploymentAccess"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Whitelist specific IPs for deployment
resource "azurerm_mssql_firewall_rule" "whitelist" {
  for_each = var.allow_deployment_access ? toset(var.deployment_ip_whitelist) : toset([])

  name             = "AllowIP-${replace(each.value, ".", "-")}"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = each.value
  end_ip_address   = each.value
}

# Private Endpoint
resource "azurerm_private_endpoint" "sql" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "${var.server_name}-private-endpoint"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.server_name}-privateserviceconnection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

# Diagnostic Settings for SQL Database
resource "azurerm_monitor_diagnostic_setting" "sql_database" {
  name                       = "${var.database_name}-diagnostics"
  target_resource_id         = azurerm_mssql_database.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Database logs
  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "AutomaticTuning"
  }

  enabled_log {
    category = "QueryStoreRuntimeStatistics"
  }

  enabled_log {
    category = "QueryStoreWaitStatistics"
  }

  enabled_log {
    category = "Errors"
  }

  enabled_log {
    category = "DatabaseWaitStatistics"
  }

  enabled_log {
    category = "Timeouts"
  }

  enabled_log {
    category = "Blocks"
  }

  enabled_log {
    category = "Deadlocks"
  }

  # Metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
