variable "settings" {
  type = object({
    name           = string
    resource_group = string
    environment    = string
    location       = string
    tags           = map(string)
  })
  description = "Global settings."
}

variable "site_config" {
  type = map(string)
  default = {
    java_version           = "11"
    java_container         = "JAVA"
    java_container_version = "SE"
  }
}

variable "ip_restrictions" {
  type        = list(map(string))
  description = "Access restrctions for the app service as a list of IP addresses in CIDR notation."
  default     = []
}

variable "insights_workspace_id" {
  type        = string
  description = "Id of the Log Analytics workspace that application insights will use."
  default     = null
}

variable "insights_daily_data_cap_in_gb" {
  type        = number
  description = "Limit the amount of data ingested for this application insights resource."
  default     = 5
}

variable "insights_type" {
  type    = string
  default = "java"
}

variable "subnet_id" {
  type        = string
  description = "Subnet id for connecting to a virtual network."
  default     = null
}

variable "kind" {
  type    = string
  default = "Windows"
}

variable "zone_redundant" {
  type    = bool
  default = false
}

variable "https_only" {
  type = bool
  default = true
}

variable "sku" {
  type = object({
    tier     = string
    size     = string
    capacity = number
  })
}

variable "hybrid_connections" {
  type = map(object({
    hostname = string
    port     = string
  }))
  default = {}
}

variable "app_settings" {
  type    = map(string)
  default = {}
}

variable "skip_alerts" {
  type    = bool
  default = false
}

variable "is_function" {
  type    = bool
  default = false
}

variable "diagnostic_categories" {
  type = object({
    logs    = list(string)
    metrics = list(string)
  })
  default = {
    logs = null
    metrics = null
  }
}
