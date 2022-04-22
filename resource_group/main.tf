locals {
  config = {
    name           = var.config.global.name
    location       = var.config.global.location

    tags = merge({
      application       = var.config.global.name
      environment       = var.environment
      terraform         = "true"
    }, var.tags)
  }
}

resource "azurecaf_name" "resource_group" {
  name           = local.config.name
  resource_type  = "azurerm_resource_group"
  suffixes       = [var.environment]
}

resource "azurerm_resource_group" "this" {
  name     = azurecaf_name.resource_group.result
  location = local.config.location
  tags     = local.config.tags
}
