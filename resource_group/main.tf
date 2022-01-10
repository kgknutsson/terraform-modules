resource "azurecaf_name" "resource_group" {
  name           = var.settings.name
  resource_type  = "azurerm_resource_group"
  suffixes       = [var.settings.environment]
}

resource "azurerm_resource_group" "this" {
  name     = azurecaf_name.resource_group.result
  location = var.settings.location
  tags     = var.settings.tags
}
