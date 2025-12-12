output "security_group_id" {
  description = "Object ID of the security group"
  value       = azuread_group.security.object_id
}

output "security_group_name" {
  description = "Name of the security group"
  value       = azuread_group.security.display_name
}

output "api_app_id" {
  description = "Application (client) ID of the API app registration"
  value       = azuread_application.api.client_id
}

output "api_object_id" {
  description = "Object ID of the API app registration"
  value       = azuread_application.api.object_id
}

output "api_client_secret" {
  description = "Client secret for the API app registration"
  value       = azuread_application_password.api.value
  sensitive   = true
}

output "frontend_app_id" {
  description = "Application (client) ID of the Frontend app registration"
  value       = azuread_application.frontend.client_id
}

output "frontend_object_id" {
  description = "Object ID of the Frontend app registration"
  value       = azuread_application.frontend.object_id
}

output "frontend_client_secret" {
  description = "Client secret for the Frontend app registration"
  value       = azuread_application_password.frontend.value
  sensitive   = true
}
