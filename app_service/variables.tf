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

// TODO: Jag hade lagt en description på alla dessa variabler för tydlighetsskull när fler börjar jobba

variable "site_config" {
  type = map(string)
  default = {
    java_version           = "11" // TODO: Bör dessa vara hårdkodade? Beror helt på hur er stack ser ut, om de verkligen bara är Java SE11 appar go for it
    java_container         = "JAVA"
    java_container_version = "SE"
  }
}

variable "kind" {
  type    = string
  default = "Windows"
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
