locals {
  config = {
    name     = var.config.global.name
    location = var.config.global.location
    zone = var.config.global.dns.zone
  }
}

resource "azurerm_dns_zone" "zone" {
  name                = local.config.zone
  resource_group_name = var.resource_group
}
