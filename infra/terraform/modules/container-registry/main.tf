# Azure Container Registry Module

resource "azurerm_container_registry" "main" {
  name                = var.registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = true

  tags = var.tags
}

# Diagnostic Settings for Container Registry
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "${var.registry_name}-diagnostics"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Container Registry logs
  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  # Metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
