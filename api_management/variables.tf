variable "config" {
  type        = any
  description = <<-EOT
  (Required) Module configuration (version 1).
  Configuration should have global settings and preferably environment specific settings for dev, prod etc.
  EOT

  validation {
    condition     = var.config.version == 1
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
    condition     = var.environment == lower(replace(var.environment, " ", ""))
    error_message = "Validation failed: Value for environment is not valid."
  }
}

variable "tags" {
  type        = map(string)
  description = <<-EOT
  (Optional) Tags to add to resources created by the module.
  Tags are key-value pair strings that can be used to categorise and group resources. The module add som tags by defalt which cannot be set manually (application, environment and terraform).
  EOT
  default     = {}

  validation {
    condition     = length(setintersection(keys(var.tags), ["environment", "terraform"])) == 0
    error_message = "Validation failed: One or more tags conflict with default tags set by the module."
  }
}

variable "resource_group" {
  type        = object({
    id       = string
    name     = string
    location = string
  })
  description = <<-EOT
  (Optional) Resource group to create new resources in.

  Resource Group resources created outside this module.
  EOT
  default = null
}

variable "app_service" {
  type        = object({
    application_insights_resource_id       = optional(string)
    application_insights_connection_string = optional(string)
  })
  description = <<-EOT
  (Optional) Shared app service resources.

  App Service resources created outside this module.
  EOT
  default     = null
}
