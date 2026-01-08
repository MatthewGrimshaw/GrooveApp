# Local variables
locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Application = "GrooveApp"
    }
  )
}
