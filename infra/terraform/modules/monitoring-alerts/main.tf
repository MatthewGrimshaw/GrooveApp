# Azure Monitor Baseline Alerts Module
# Based on: https://azure.github.io/azure-monitor-baseline-alerts/services/

locals {
  # Common alert properties
  common_tags = var.tags

  # Action group for alert notifications
  action_group_id = azurerm_monitor_action_group.main.id
}

# Action Group for Alert Notifications
resource "azurerm_monitor_action_group" "main" {
  name                = var.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = var.action_group_short_name

  # Email notifications
  dynamic "email_receiver" {
    for_each = var.email_receivers
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = true
    }
  }

  # Webhook notifications (e.g., Teams, Slack)
  dynamic "webhook_receiver" {
    for_each = var.webhook_receivers
    content {
      name                    = webhook_receiver.value.name
      service_uri             = webhook_receiver.value.service_uri
      use_common_alert_schema = true
    }
  }

  tags = local.common_tags
}

# ============================================================================
# APP SERVICE PLAN ALERTS (serverFarms)
# ============================================================================

resource "azurerm_monitor_metric_alert" "app_service_plan_cpu" {
  count               = var.app_service_plan_id != null ? 1 : 0
  name                = "${var.naming_prefix}-asp-cpu-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_service_plan_id]
  description         = "Alert when CPU percentage exceeds 90% (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_app_service_plan_alerts

  criteria {
    metric_namespace = "Microsoft.Web/serverFarms"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.app_service_plan_cpu_threshold
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "app_service_plan_memory" {
  count               = var.app_service_plan_id != null ? 1 : 0
  name                = "${var.naming_prefix}-asp-memory-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_service_plan_id]
  description         = "Alert when memory percentage exceeds 90% (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_app_service_plan_alerts

  criteria {
    metric_namespace = "Microsoft.Web/serverFarms"
    metric_name      = "MemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.app_service_plan_memory_threshold
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "app_service_plan_http_queue" {
  count               = var.app_service_plan_id != null ? 1 : 0
  name                = "${var.naming_prefix}-asp-httpqueue-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_service_plan_id]
  description         = "Alert when HTTP queue length exceeds 100 (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_app_service_plan_alerts

  criteria {
    metric_namespace = "Microsoft.Web/serverFarms"
    metric_name      = "HttpQueueLength"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 100
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

# ============================================================================
# APP SERVICE (WEB APP) ALERTS (sites)
# ============================================================================

# Alert for each web app
resource "azurerm_monitor_metric_alert" "web_app_response_time" {
  for_each            = var.web_app_ids
  name                = "${var.naming_prefix}-${each.key}-response-time-alert"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when average response time exceeds 60 seconds (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_web_app_alerts

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "AverageResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 60
  }

  frequency   = "PT5M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

# NOTE: Http5xx and Http4xx metrics are not available for containerized Linux App Services
# Use Application Insights or Log Analytics queries instead for HTTP error monitoring
/*
resource "azurerm_monitor_metric_alert" "web_app_http_5xx" {
  for_each            = var.web_app_ids
  name                = "${var.naming_prefix}-${each.key}-http5xx-alert"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when HTTP 5xx errors exceed 10 in 15 minutes (AMBA recommendation)"
  severity            = 1
  enabled             = var.enable_web_app_alerts

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  frequency   = "PT5M"
  window_size = "PT15M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "web_app_http_4xx" {
  for_each            = var.web_app_ids
  name                = "${var.naming_prefix}-${each.key}-http4xx-alert"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when HTTP 4xx errors average exceeds 5 (AMBA recommendation)"
  severity            = 1
  enabled             = var.enable_web_app_alerts

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http4xx"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 5
  }

  frequency   = "PT15M"
  window_size = "PT30M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}
*/

resource "azurerm_monitor_metric_alert" "web_app_memory" {
  for_each            = var.web_app_ids
  name                = "${var.naming_prefix}-${each.key}-memory-alert"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when memory working set exceeds 1.5GB (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_web_app_alerts

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "MemoryWorkingSet"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 1500000000 # 1.5GB in bytes
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "web_app_cpu_time" {
  for_each            = var.web_app_ids
  name                = "${var.naming_prefix}-${each.key}-cputime-alert"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when CPU time exceeds 120 seconds in 5 minutes (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_web_app_alerts

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "CpuTime"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 120
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

# ============================================================================
# AZURE SQL DATABASE ALERTS
# ============================================================================

resource "azurerm_monitor_metric_alert" "sql_cpu" {
  count               = var.sql_database_id != null ? 1 : 0
  name                = "${var.naming_prefix}-sql-cpu-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.sql_database_id]
  description         = "Alert when SQL CPU exceeds 80% (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_sql_alerts

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "sql_memory" {
  count               = var.sql_database_id != null ? 1 : 0
  name                = "${var.naming_prefix}-sql-memory-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.sql_database_id]
  description         = "Alert when SQL memory exceeds 90% (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_sql_alerts

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "sql_instance_memory_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }

  frequency   = "PT5M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "sql_connection_failed" {
  count               = var.sql_database_id != null ? 1 : 0
  name                = "${var.naming_prefix}-sql-connfail-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.sql_database_id]
  description         = "Alert when failed connections exceed 5 (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_sql_alerts

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "connection_failed"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "sql_deadlock" {
  count               = var.sql_database_id != null ? 1 : 0
  name                = "${var.naming_prefix}-sql-deadlock-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.sql_database_id]
  description         = "Alert when deadlocks occur (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_sql_alerts

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "deadlock"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 1
  }

  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "sql_storage" {
  count               = var.sql_database_id != null ? 1 : 0
  name                = "${var.naming_prefix}-sql-storage-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.sql_database_id]
  description         = "Alert when storage exceeds 870GB (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_sql_alerts

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "storage"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = 934584883610 # ~870GB in bytes
  }

  frequency   = "PT5M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "sql_blocked_by_firewall" {
  count               = var.sql_database_id != null ? 1 : 0
  name                = "${var.naming_prefix}-sql-firewall-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.sql_database_id]
  description         = "Alert when connections blocked by firewall exceed 5 (AMBA recommendation)"
  severity            = 2
  enabled             = var.enable_sql_alerts

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "blocked_by_firewall"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  frequency   = "PT5M"
  window_size = "PT5M"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

# ============================================================================
# CONTAINER REGISTRY ALERTS
# ============================================================================

resource "azurerm_monitor_metric_alert" "acr_storage" {
  count               = var.container_registry_id != null ? 1 : 0
  name                = "${var.naming_prefix}-acr-storage-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.container_registry_id]
  description         = "Alert when ACR storage exceeds 400GB (AMBA recommendation)"
  severity            = 3
  enabled             = var.enable_acr_alerts

  criteria {
    metric_namespace = "Microsoft.ContainerRegistry/registries"
    metric_name      = "StorageUsed"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 429496729600 # 400GB in bytes
  }

  frequency   = "PT5M"
  window_size = "PT1H"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}

# ============================================================================
# LOG ANALYTICS WORKSPACE ALERTS (Optional)
# ============================================================================

resource "azurerm_monitor_metric_alert" "log_analytics_ingestion" {
  count               = var.log_analytics_workspace_id != null && var.enable_log_analytics_alerts ? 1 : 0
  name                = "${var.naming_prefix}-law-ingestion-alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.log_analytics_workspace_id]
  description         = "Alert when daily data ingestion exceeds threshold"
  severity            = 2
  enabled             = true

  dynamic_criteria {
    metric_namespace  = "Microsoft.OperationalInsights/workspaces"
    metric_name       = "IngestionVolumeMB"
    aggregation       = "Total"
    operator          = "GreaterThan"
    alert_sensitivity = "Medium"
  }

  frequency   = "PT5M"
  window_size = "PT1H"

  action {
    action_group_id = local.action_group_id
  }

  tags = local.common_tags
}
