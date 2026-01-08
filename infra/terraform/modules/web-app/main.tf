# Azure Web App Module

resource "azurerm_linux_web_app" "main" {
  name                = var.app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = var.service_plan_id

  site_config {
    always_on = var.always_on

    application_stack {
      docker_image_name        = var.docker_image
      docker_registry_url      = "https://${var.acr_login_server}"
      docker_registry_username = var.acr_username
      docker_registry_password = var.acr_password
    }

    health_check_path = var.health_check_path

    # CORS configuration
    dynamic "cors" {
      for_each = length(var.cors_allowed_origins) > 0 ? [1] : []
      content {
        allowed_origins     = var.cors_allowed_origins
        support_credentials = var.cors_support_credentials
      }
    }
  }

  app_settings = merge(
    var.app_settings,
    var.enable_authentication ? {
      MICROSOFT_PROVIDER_AUTHENTICATION_SECRET = var.client_secret
    } : {}
  )

  identity {
    type = "SystemAssigned"
  }

  # Easy Auth configuration on main app
  dynamic "auth_settings_v2" {
    for_each = var.enable_authentication ? [1] : []
    content {
      auth_enabled           = true
      require_authentication = true
      unauthenticated_action = var.unauthenticated_action

      login {
        token_store_enabled = true
      }

      active_directory_v2 {
        client_id            = var.client_id
        tenant_auth_endpoint = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"

        allowed_audiences = [
          "api://${var.client_id}"
        ]
      }
    }
  }

  https_only = true

  tags = var.tags
}

# VNet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "main" {
  count = var.enable_vnet_integration ? 1 : 0

  app_service_id = azurerm_linux_web_app.main.id
  subnet_id      = var.vnet_integration_subnet_id
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "web_app" {
  name                       = "${var.app_name}-diagnostics"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # HTTP Logs
  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  # Console Logs
  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  # Application Logs
  enabled_log {
    category = "AppServiceAppLogs"
  }

  # Platform Logs
  enabled_log {
    category = "AppServicePlatformLogs"
  }

  # Audit Logs
  enabled_log {
    category = "AppServiceAuditLogs"
  }

  # IP Security Audit Logs
  enabled_log {
    category = "AppServiceIPSecAuditLogs"
  }

  # Metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
