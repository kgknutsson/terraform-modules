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

variable "address_space" {
  type        = list(string)
  description = "The Azure Virtual Network address spaces in CIDR notation"
}

variable "subnets" {
  type = map(object({
    address_prefixes            = list(string)
    service_endpoints           = list(string)
    service_delegation          = string
    private_connection_resource = object({id = string, name = string})
    subresource_names           = list(string)
    is_manual_connection        = bool
  }))
}
