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
