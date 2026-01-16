# Example Integration of Monitoring Alerts Module
# Add this to your main.tf file after your existing modules

# ============================================================================
# AZURE MONITOR BASELINE ALERTS
# Based on: https://azure.github.io/azure-monitor-baseline-alerts/services/
# ============================================================================

module "monitoring_alerts" {
  source = "./modules/monitoring-alerts"

  resource_group_name = azurerm_resource_group.main.name
  naming_prefix       = "${var.naming_prefix}-${var.environment}"

  # Action Group Configuration
  action_group_name       = "${var.naming_prefix}-${var.environment}-alerts"
  action_group_short_name = var.environment == "prod" ? "ga-prod" : (var.environment == "staging" ? "ga-stage" : "ga-dev")

  # Email notifications - customize with your team's emails
  email_receivers = var.alert_email_receivers

  # Optional: Webhook notifications (Teams, Slack, etc.)
  webhook_receivers = var.alert_webhook_receivers

  # Resource IDs to monitor
  app_service_plan_id = module.app_service_plan.id

  web_app_ids = {
    api      = module.api_web_app.id
    frontend = module.frontend_web_app.id
  }

  # Conditional resources based on database type
  sql_database_id = var.database_type == "sql" ? module.database_sql[0].database_id : null

  container_registry_id = module.container_registry.id

  log_analytics_workspace_id = module.log_analytics.workspace_id

  # Enable/Disable alert categories
  enable_app_service_plan_alerts = var.enable_app_service_plan_alerts
  enable_web_app_alerts          = var.enable_web_app_alerts
  enable_sql_alerts              = var.database_type == "sql" && var.enable_sql_alerts
  enable_acr_alerts              = var.enable_acr_alerts
  enable_log_analytics_alerts    = var.enable_log_analytics_alerts

  # Optional: Override default AMBA thresholds
  app_service_plan_cpu_threshold    = var.environment == "prod" ? 80 : 90
  app_service_plan_memory_threshold = var.environment == "prod" ? 85 : 90

  tags = local.common_tags
}
