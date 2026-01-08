# Network Module Outputs

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "app_service_subnet_id" {
  description = "ID of the App Service subnet"
  value       = azurerm_subnet.app_service.id
}

output "private_endpoint_subnet_id" {
  description = "ID of the Private Endpoint subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "sql_private_dns_zone_id" {
  description = "ID of the SQL Private DNS zone"
  value       = var.enable_sql_dns ? azurerm_private_dns_zone.sql[0].id : null
}

output "postgres_private_dns_zone_id" {
  description = "ID of the PostgreSQL Private DNS zone"
  value       = var.enable_postgres_dns ? azurerm_private_dns_zone.postgres[0].id : null
}
