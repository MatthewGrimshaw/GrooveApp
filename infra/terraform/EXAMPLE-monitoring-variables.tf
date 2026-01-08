# Additional Variables for Monitoring Alerts Module
# Add these to your variables.tf file

# ============================================================================
# MONITORING ALERTS CONFIGURATION
# ============================================================================

variable "alert_email_receivers" {
  description = "List of email addresses to receive alert notifications"
  type = list(object({
    name          = string
    email_address = string
  }))
  default = [
    {
      name          = "DevOps Team"
      email_address = "devops@example.com"
    }
  ]
}

variable "alert_webhook_receivers" {
  description = "List of webhook endpoints for alert notifications (Teams, Slack, etc.)"
  type = list(object({
    name        = string
    service_uri = string
  }))
  default = []
  # Example for Microsoft Teams:
  # default = [
  #   {
  #     name        = "Teams DevOps Channel"
  #     service_uri = "https://outlook.office.com/webhook/YOUR-WEBHOOK-URL"
  #   }
  # ]
}

variable "enable_app_service_plan_alerts" {
  description = "Enable App Service Plan monitoring alerts (CPU, Memory, HTTP Queue)"
  type        = bool
  default     = true
}

variable "enable_web_app_alerts" {
  description = "Enable Web App monitoring alerts (Response Time, HTTP errors, Memory, CPU)"
  type        = bool
  default     = true
}

variable "enable_sql_alerts" {
  description = "Enable SQL Database monitoring alerts (CPU, Memory, Connections, Deadlocks, Storage)"
  type        = bool
  default     = true
}

variable "enable_acr_alerts" {
  description = "Enable Container Registry monitoring alerts (Storage usage)"
  type        = bool
  default     = true
}

variable "enable_log_analytics_alerts" {
  description = "Enable Log Analytics Workspace monitoring alerts (Data ingestion)"
  type        = bool
  default     = false
}
