output "id" {
  description = "ID of the App Service Plan"
  value       = azurerm_service_plan.main.id
}

output "name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.main.name
}
