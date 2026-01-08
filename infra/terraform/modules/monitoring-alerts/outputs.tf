# Azure Monitor Baseline Alerts Module - Outputs

output "action_group_id" {
  description = "Resource ID of the action group for alert notifications"
  value       = azurerm_monitor_action_group.main.id
}

output "action_group_name" {
  description = "Name of the action group"
  value       = azurerm_monitor_action_group.main.name
}

output "alert_ids" {
  description = "Map of all created alert resource IDs"
  value = merge(
    # App Service Plan alerts
    { for k, v in azurerm_monitor_metric_alert.app_service_plan_cpu : "asp_cpu_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.app_service_plan_memory : "asp_memory_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.app_service_plan_http_queue : "asp_http_queue_${k}" => v.id },

    # Web App alerts
    { for k, v in azurerm_monitor_metric_alert.web_app_response_time : "webapp_response_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.web_app_http_5xx : "webapp_5xx_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.web_app_http_4xx : "webapp_4xx_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.web_app_memory : "webapp_memory_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.web_app_cpu_time : "webapp_cpu_${k}" => v.id },

    # SQL alerts
    { for k, v in azurerm_monitor_metric_alert.sql_cpu : "sql_cpu_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.sql_memory : "sql_memory_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.sql_connection_failed : "sql_conn_fail_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.sql_deadlock : "sql_deadlock_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.sql_storage : "sql_storage_${k}" => v.id },
    { for k, v in azurerm_monitor_metric_alert.sql_blocked_by_firewall : "sql_firewall_${k}" => v.id },

    # ACR alerts
    { for k, v in azurerm_monitor_metric_alert.acr_storage : "acr_storage_${k}" => v.id },

    # Log Analytics alerts
    { for k, v in azurerm_monitor_metric_alert.log_analytics_ingestion : "law_ingestion_${k}" => v.id }
  )
}

output "alert_count" {
  description = "Total number of alerts created"
  value = (
    length(azurerm_monitor_metric_alert.app_service_plan_cpu) +
    length(azurerm_monitor_metric_alert.app_service_plan_memory) +
    length(azurerm_monitor_metric_alert.app_service_plan_http_queue) +
    length(azurerm_monitor_metric_alert.web_app_response_time) +
    length(azurerm_monitor_metric_alert.web_app_http_5xx) +
    length(azurerm_monitor_metric_alert.web_app_http_4xx) +
    length(azurerm_monitor_metric_alert.web_app_memory) +
    length(azurerm_monitor_metric_alert.web_app_cpu_time) +
    length(azurerm_monitor_metric_alert.sql_cpu) +
    length(azurerm_monitor_metric_alert.sql_memory) +
    length(azurerm_monitor_metric_alert.sql_connection_failed) +
    length(azurerm_monitor_metric_alert.sql_deadlock) +
    length(azurerm_monitor_metric_alert.sql_storage) +
    length(azurerm_monitor_metric_alert.sql_blocked_by_firewall) +
    length(azurerm_monitor_metric_alert.acr_storage) +
    length(azurerm_monitor_metric_alert.log_analytics_ingestion)
  )
}
