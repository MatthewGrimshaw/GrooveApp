# Entra ID (Azure AD) Module

# Security Group
resource "azuread_group" "security" {
  display_name     = var.security_group_name
  security_enabled = true
  description      = "Security group for ${var.app_name} access"

  mail_enabled = false
}

# API App Registration
resource "azuread_application" "api" {
  display_name     = "${var.app_name}-api"
  sign_in_audience = "AzureADMyOrg"

  web {
    redirect_uris = [
      "${var.api_url}/.auth/login/aad/callback"
    ]

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  group_membership_claims = ["SecurityGroup"]

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "api" {
  client_id = azuread_application.api.client_id
}

resource "azuread_application_password" "api" {
  application_id = azuread_application.api.id
  display_name   = "Terraform managed secret"
  end_date       = timeadd(timestamp(), "8760h") # 1 year
}

# Frontend App Registration
resource "azuread_application" "frontend" {
  display_name     = "${var.app_name}-frontend"
  sign_in_audience = "AzureADMyOrg"

  single_page_application {
    redirect_uris = [
      var.frontend_url,
      "${var.frontend_url}/auth/callback"
    ]
  }

  group_membership_claims = ["SecurityGroup"]

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "frontend" {
  client_id = azuread_application.frontend.client_id
}

resource "azuread_application_password" "frontend" {
  application_id = azuread_application.frontend.id
  display_name   = "Terraform managed secret"
  end_date       = timeadd(timestamp(), "8760h") # 1 year
}
