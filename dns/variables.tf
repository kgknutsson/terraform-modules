
variable "config" {
  type = any
  description = <<-EOT
  (Required) Module configuration (version 1).

  Configuration should have global settings and preferably environment specific settings for dev, prod etc.
  EOT

  validation {
    condition = var.config.version == 1
    error_message = "Configuration must be version 1."
  }
}

variable "environment" {
  type        = string
  description = <<-EOT
  (Required) Environment name.

  Must be a single short word, all lowercase, eg. dev.
  EOT

  validation {
    condition = var.environment == lower(replace(var.environment, " ", ""))
    error_message = "Validation failed: Value for environment is not valid."
  }
}

variable "resource_group" {
  type = string
  description = <<-EOT
  (Required) Resource group where resources are to be created.

  Resource group name already created outside this module.
  EOT
}
