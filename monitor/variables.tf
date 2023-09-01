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
  type = map(string)
  description = <<-EOT
  (Required) Resource group where resources are to be created.

  The name of a resource group already created outside this module.
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

variable "monitor_config" {
  type        = object({
    autoscale_settings  = optional(list(any), [])
    diagnostic_settings = optional(list(any), [])
    activity_log_alerts = optional(list(object({
      name                                                         = string
      formatted_name                                               = optional(string)
      scopes                                                       = list(string)
      description                                                  = optional(string)
      enabled                                                      = optional(bool)
      criteria                                                     = any
      action                                                       = optional(any, [])
    })), [])
    metric_alerts       = optional(list(object({
      name                                                         = string
      formatted_name                                               = optional(string)
      scopes                                                       = list(string)
      description                                                  = optional(string)
      severity                                                     = optional(string)
      target_resource_type                                         = optional(string)
      target_resource_location                                     = optional(string)
      frequency                                                    = optional(string)
      window_size                                                  = optional(string)
      auto_mitigate                                                = optional(bool)
      enabled                                                      = optional(bool)
      criteria                                                     = optional(any, [])
      dynamic_criteria                                             = optional(any, [])
      application_insights_web_test_location_availability_criteria = optional(any, [])
      action                                                       = optional(any, [])
    })), [])
  })
  description = <<-EOT
  (Optional) Monitor configuration.

  Lists of autoscale settings, diagnostic settings and/or metric alerts.
  EOT
  default     = null
}
