output "id" {
  description = "ID of the Web App"
  value       = azurerm_linux_web_app.main.id
}

output "name" {
  description = "Name of the Web App"
  value       = azurerm_linux_web_app.main.name
}

output "default_hostname" {
  description = "Default hostname of the Web App"
  value       = azurerm_linux_web_app.main.default_hostname
}

output "identity_principal_id" {
  description = "Principal ID of the Web App managed identity"
  value       = azurerm_linux_web_app.main.identity[0].principal_id
}

output "identity_tenant_id" {
  description = "Tenant ID of the Web App managed identity"
  value       = azurerm_linux_web_app.main.identity[0].tenant_id
}

output "outbound_ip_addresses" {
  description = "Outbound IP addresses of the Web App"
  value       = azurerm_linux_web_app.main.outbound_ip_addresses
}

output "staging_slot_id" {
  description = "ID of the staging slot (if created)"
  value       = var.supports_deployment_slots ? azurerm_linux_web_app_slot.staging[0].id : null
}

output "staging_slot_name" {
  description = "Name of the staging slot (if created)"
  value       = var.supports_deployment_slots ? azurerm_linux_web_app_slot.staging[0].name : null
}

output "staging_slot_hostname" {
  description = "Hostname of the staging slot (if created)"
  value       = var.supports_deployment_slots ? azurerm_linux_web_app_slot.staging[0].default_hostname : null
}

output "staging_slot_principal_id" {
  description = "Principal ID of the staging slot managed identity (if created)"
  value       = var.supports_deployment_slots ? azurerm_linux_web_app_slot.staging[0].identity[0].principal_id : null
}
