# Azure Log Analytics Workspace Module

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  retention_in_days   = var.retention_in_days

  tags = var.tags
}

# Application Insights (linked to Log Analytics)
resource "azurerm_application_insights" "main" {
  name                = var.app_insights_name
  resource_group_name = var.resource_group_name
  location            = var.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = var.tags
}
