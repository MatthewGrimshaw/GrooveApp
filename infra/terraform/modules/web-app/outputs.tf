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
