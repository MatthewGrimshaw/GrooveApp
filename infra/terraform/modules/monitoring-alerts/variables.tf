# Azure Monitor Baseline Alerts Module - Variables
# Based on: https://azure.github.io/azure-monitor-baseline-alerts/services/

variable "resource_group_name" {
  description = "Name of the resource group for the alerts"
  type        = string
}

variable "naming_prefix" {
  description = "Prefix for alert names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to alert resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# ACTION GROUP CONFIGURATION
# ============================================================================

variable "action_group_name" {
  description = "Name of the action group for alert notifications"
  type        = string
}

variable "action_group_short_name" {
  description = "Short name for the action group (max 12 characters)"
  type        = string
  validation {
    condition     = length(var.action_group_short_name) <= 12
    error_message = "Action group short name must be 12 characters or less."
  }
}

variable "email_receivers" {
  description = "List of email receivers for alert notifications"
  type = list(object({
    name          = string
    email_address = string
  }))
  default = []
}

variable "webhook_receivers" {
  description = "List of webhook receivers (e.g., Teams, Slack) for alert notifications"
  type = list(object({
    name        = string
    service_uri = string
  }))
  default = []
}

# ============================================================================
# RESOURCE IDS
# ============================================================================

variable "app_service_plan_id" {
  description = "Resource ID of the App Service Plan to monitor"
  type        = string
  default     = null
}

variable "web_app_ids" {
  description = "Map of web app names to resource IDs to monitor (e.g., { 'api' = '/subscriptions/.../resourceGroups/.../providers/Microsoft.Web/sites/app-api', 'frontend' = '...' })"
  type        = map(string)
  default     = {}
}

variable "sql_database_id" {
  description = "Resource ID of the SQL Database to monitor"
  type        = string
  default     = null
}

variable "container_registry_id" {
  description = "Resource ID of the Container Registry to monitor"
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace to monitor"
  type        = string
  default     = null
}

# ============================================================================
# ALERT ENABLEMENT FLAGS
# ============================================================================

variable "enable_app_service_plan_alerts" {
  description = "Enable App Service Plan alerts (CPU, Memory, HTTP Queue)"
  type        = bool
  default     = true
}

variable "enable_web_app_alerts" {
  description = "Enable Web App alerts (Response Time, HTTP errors, Memory, CPU)"
  type        = bool
  default     = true
}

variable "enable_sql_alerts" {
  description = "Enable SQL Database alerts (CPU, Memory, Connections, Deadlocks, Storage)"
  type        = bool
  default     = true
}

variable "enable_acr_alerts" {
  description = "Enable Container Registry alerts (Storage)"
  type        = bool
  default     = true
}

variable "enable_log_analytics_alerts" {
  description = "Enable Log Analytics Workspace alerts (Data Ingestion)"
  type        = bool
  default     = false
}

# ============================================================================
# CUSTOM THRESHOLDS (Override AMBA defaults if needed)
# ============================================================================

variable "app_service_plan_cpu_threshold" {
  description = "CPU percentage threshold for App Service Plan (AMBA default: 90)"
  type        = number
  default     = 90
}

variable "app_service_plan_memory_threshold" {
  description = "Memory percentage threshold for App Service Plan (AMBA default: 90)"
  type        = number
  default     = 90
}
