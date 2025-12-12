output "server_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "server_id" {
  description = "ID of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.id
}

output "server_name" {
  description = "Name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "database_name" {
  description = "Name of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "database_id" {
  description = "ID of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.main.id
}

output "admin_username" {
  description = "Administrator username"
  value       = var.admin_username
  sensitive   = true
}
