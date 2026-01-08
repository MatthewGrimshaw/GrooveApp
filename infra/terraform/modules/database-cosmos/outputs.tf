output "endpoint" {
  description = "Endpoint URL for Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "account_id" {
  description = "ID of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.id
}

output "account_name" {
  description = "Name of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.name
}

output "database_name" {
  description = "Name of the Cosmos DB database"
  value       = azurerm_cosmosdb_sql_database.main.name
}

output "database_id" {
  description = "ID of the Cosmos DB database"
  value       = azurerm_cosmosdb_sql_database.main.id
}

output "primary_key" {
  description = "Primary master key for Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}
