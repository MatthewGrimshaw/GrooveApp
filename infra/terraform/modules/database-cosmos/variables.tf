variable "account_name" {
  description = "Name of the Cosmos DB account"
  type        = string
}

variable "database_name" {
  description = "Name of the Cosmos DB database"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "consistency_level" {
  description = "Consistency level for Cosmos DB (Eventual, Session, Strong, BoundedStaleness, ConsistentPrefix)"
  type        = string
  default     = "Session"

  validation {
    condition     = contains(["Eventual", "Session", "Strong", "BoundedStaleness", "ConsistentPrefix"], var.consistency_level)
    error_message = "Consistency level must be one of: Eventual, Session, Strong, BoundedStaleness, ConsistentPrefix."
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for diagnostic settings"
  type        = string
}
