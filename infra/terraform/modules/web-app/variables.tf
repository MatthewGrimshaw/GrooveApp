variable "app_name" {
  description = "Name of the Web App"
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

variable "service_plan_id" {
  description = "ID of the App Service Plan"
  type        = string
}

variable "docker_image" {
  description = "Docker image to deploy (image:tag format)"
  type        = string
}

variable "acr_login_server" {
  description = "Login server for Azure Container Registry"
  type        = string
}

variable "acr_username" {
  description = "Username for Azure Container Registry"
  type        = string
  sensitive   = true
}

variable "acr_password" {
  description = "Password for Azure Container Registry"
  type        = string
  sensitive   = true
}

variable "app_settings" {
  description = "Application settings for the Web App"
  type        = map(string)
  default     = {}
}

variable "always_on" {
  description = "Should the app be always on"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

variable "enable_authentication" {
  description = "Enable Easy Auth with Azure AD"
  type        = bool
  default     = false
}

variable "supports_deployment_slots" {
  description = "Whether the App Service Plan SKU supports deployment slots (Standard/Premium, not Basic)"
  type        = bool
  default     = false
}

variable "tenant_id" {
  description = "Azure AD tenant ID (required if enable_authentication is true)"
  type        = string
  default     = ""
}

variable "client_id" {
  description = "Azure AD application (client) ID (required if enable_authentication is true)"
  type        = string
  default     = ""
}

variable "client_secret" {
  description = "Azure AD application client secret (required if enable_authentication is true)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "vnet_integration_subnet_id" {
  description = "Subnet ID for VNet integration"
  type        = string
  default     = ""
}

variable "enable_vnet_integration" {
  description = "Enable VNet integration for the app"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for diagnostic settings"
  type        = string
}

variable "cors_allowed_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = []
}

variable "cors_support_credentials" {
  description = "Whether to allow credentials in CORS requests"
  type        = bool
  default     = false
}

variable "unauthenticated_action" {
  description = "Action to take when request is not authenticated (RedirectToLoginPage or Return401)"
  type        = string
  default     = "RedirectToLoginPage"
}
