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

  https_only = true

  tags = var.tags
}

# Easy Auth configuration
resource "azurerm_linux_web_app_slot" "auth_config" {
  count = var.enable_authentication ? 1 : 0

  name           = "auth"
  app_service_id = azurerm_linux_web_app.main.id

  site_config {
    always_on = false
  }

  auth_settings_v2 {
    auth_enabled           = true
    require_authentication = true
    unauthenticated_action = "RedirectToLoginPage"

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
