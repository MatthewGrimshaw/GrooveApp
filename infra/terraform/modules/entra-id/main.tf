# Entra ID (Azure AD) Module
# Fully Terraform-native implementation

# Security Group
resource "azuread_group" "security" {
  display_name     = var.security_group_name
  security_enabled = true
  description      = "Security group for ${var.app_name} access"
  mail_enabled     = false
}

# ====================================
# API App Registration
# ====================================

resource "azuread_application" "api" {
  display_name     = "${var.app_name}-api"
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner_object_id]

  # Set the identifier URI using app client_id to comply with tenant policy
  # Cannot set until after app is created, so this will be set in a lifecycle block
  # identifier_uris will be set after client_id is known

  web {
    redirect_uris = concat(
      [
        "${var.api_url}/.auth/login/aad/callback"
      ],
      var.supports_deployment_slots ? [
        "${replace(var.api_url, ".azurewebsites.net", "-staging.azurewebsites.net")}/.auth/login/aad/callback"
      ] : []
    )

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  # Expose API scopes that the frontend can request
  api {
    # Define delegated permissions (scopes) for the API
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access the API on behalf of the signed-in user"
      admin_consent_display_name = "Access API"
      enabled                    = true
      id                         = "a0a0a0a0-bbbb-cccc-dddd-e1e1e1e1e1e1" # Random GUID, keep consistent
      type                       = "User"
      user_consent_description   = "Allow the application to access the API on your behalf"
      user_consent_display_name  = "Access API"
      value                      = "user_impersonation"
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

  # Set identifier URI using client_id to comply with tenant policy
  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

# Update identifier_uris after app creation to use client_id
resource "azuread_application_identifier_uri" "api" {
  application_id = azuread_application.api.id
  identifier_uri = "api://${azuread_application.api.client_id}"
}

# Service Principal for API
resource "azuread_service_principal" "api" {
  client_id                    = azuread_application.api.client_id
  app_role_assignment_required = false
  owners                       = [var.owner_object_id]
}

# Client Secret for API (Terraform-native)
resource "azuread_application_password" "api" {
  application_id = azuread_application.api.id
  display_name   = "Terraform-managed secret"
  end_date       = timeadd(timestamp(), "8760h") # 1 year from now

  lifecycle {
    ignore_changes = [end_date] # Prevent rotation on every apply
  }
}

# ====================================
# Frontend App Registration
# ====================================

resource "azuread_application" "frontend" {
  display_name     = "${var.app_name}-frontend"
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner_object_id]

  web {
    redirect_uris = concat(
      [
        "${var.frontend_url}/.auth/login/aad/callback"
      ],
      var.supports_deployment_slots ? [
        "${replace(var.frontend_url, ".azurewebsites.net", "-staging.azurewebsites.net")}/.auth/login/aad/callback"
      ] : []
    )

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  group_membership_claims = ["SecurityGroup"]

  # Request permission to call Microsoft Graph
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

  # Request permission to call the API on behalf of the user
  required_resource_access {
    resource_app_id = azuread_application.api.client_id # Our API

    resource_access {
      id   = "a0a0a0a0-bbbb-cccc-dddd-e1e1e1e1e1e1" # user_impersonation scope (matches API definition)
      type = "Scope"
    }
  }
}

# Service Principal for Frontend
resource "azuread_service_principal" "frontend" {
  client_id                    = azuread_application.frontend.client_id
  app_role_assignment_required = false
  owners                       = [var.owner_object_id]
}

# Client Secret for Frontend (Terraform-native)
resource "azuread_application_password" "frontend" {
  application_id = azuread_application.frontend.id
  display_name   = "Terraform-managed secret"
  end_date       = timeadd(timestamp(), "8760h") # 1 year from now

  lifecycle {
    ignore_changes = [end_date] # Prevent rotation on every apply
  }
}

