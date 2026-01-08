variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "security_group_name" {
  description = "Name of the security group"
  type        = string
}

variable "api_url" {
  description = "URL of the API application"
  type        = string
}

variable "frontend_url" {
  description = "URL of the frontend application"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "owner_object_id" {
  description = "Object ID of the user to set as owner of app registrations"
  type        = string
}

variable "supports_deployment_slots" {
  description = "Whether deployment slots are supported (enables staging slot redirect URIs)"
  type        = bool
  default     = false
}

variable "supports_deployment_slots" {
  description = "Whether deployment slots are supported (enables staging slot redirect URIs)"
  type        = bool
  default     = false
}
