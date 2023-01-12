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


variable "tags" {
  type        = map(string)
  description = <<-EOT
  (Optional) Tags to add to resources created by the module.

  Tags are key-value pair strings that can be used to categorise and group resources. The module add som tags by defalt which cannot be set manually (application, environment and terraform).
  EOT
  default = {}

  validation {
    condition = length(setintersection(keys(var.tags), ["application", "environment", "terraform"])) == 0
    error_message = "Validation failed: One or more tags conflict with default tags set by the module."
  }
}

variable "service_plan_id" {
  type        = string
  description = <<-EOT
  (Optional) Service Plan which will be used to host this app.

  Service Plan created outside this module.
  EOT
  default     = null
}

variable "application_insights_connection_string" {
  type        = string
  description = <<-EOT
  (Optional) Application Insights connection string.

  Application Insights resource created outside this module.
  EOT
  default     = null
}

variable "subnet_ids" {
  type        = map(string)
  description = <<-EOT
  (Optional) Subnet ids for the virtual network to integrate with.

  Subnet seclection will be based on configuration set in app_service.site_config.vnet_integration_subnet.
  EOT
  default     = {}
}

variable "storage_account" {
  type        = object({
    name       = string
    access_key = string
  })
  description = <<-EOT
  (Optional) The backend storage account which will be used by this Function App.

  Storage Account created outside this module.
  EOT
  default     = null
}
