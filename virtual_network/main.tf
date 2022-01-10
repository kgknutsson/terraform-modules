resource "azurecaf_name" "virtual_network" {
  name          = var.settings.name
  resource_type = "azurerm_virtual_network"
  suffixes      = [var.settings.environment]
}

resource "azurerm_virtual_network" "this" {
  name                = azurecaf_name.virtual_network.result
  location            = var.settings.location
  resource_group_name = var.settings.resource_group
  address_space       = var.address_space
  tags                = var.settings.tags
}

resource "azurecaf_name" "subnet" {
  for_each = var.subnets

  name          = each.key
  resource_type = "azurerm_subnet"
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = azurecaf_name.subnet[each.key].result
  resource_group_name  = azurerm_virtual_network.this.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints

  dynamic "delegation" {
    for_each = each.value.service_delegation[*]
    
    content {
      name = "delegation"

      service_delegation {
        name    = delegation.value
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }

  enforce_private_link_endpoint_network_policies = length(each.value.private_connection_resource[*]) == 1
}

resource "azurerm_private_dns_zone" "this" {
  count = anytrue(values(azurerm_subnet.this)[*].enforce_private_link_endpoint_network_policies) ? 1 : 0

  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_virtual_network.this.resource_group_name
  tags                = var.settings.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count = length(azurerm_private_dns_zone.this)

  name                  = azurerm_virtual_network.this.name
  resource_group_name   = azurerm_virtual_network.this.resource_group_name
  private_dns_zone_name = "privatelink.database.windows.net"
  virtual_network_id    = azurerm_virtual_network.this.id
  tags                  = var.settings.tags
}

resource "azurecaf_name" "private_endpoint" {
  for_each = { for k, v in var.subnets : k => v if length(v.private_connection_resource[*]) == 1 }

  name          = each.value.private_connection_resource.name
  resource_type = "azurerm_private_endpoint"
  suffixes      = [var.settings.name]
}

resource "azurerm_private_endpoint" "this" {
  for_each = azurecaf_name.private_endpoint

  name                = each.value.result
  location            = azurerm_virtual_network.this.location
  resource_group_name = azurerm_virtual_network.this.resource_group_name
  subnet_id           = azurerm_subnet.this[each.key].id
  tags                = var.settings.tags

  private_dns_zone_group {
    name                 = "privatelink-database-windows-net"
    private_dns_zone_ids = azurerm_private_dns_zone.this[*].id
  }

  private_service_connection {
    name                           = each.value.result
    private_connection_resource_id = var.subnets[each.key].private_connection_resource.id
    subresource_names              = var.subnets[each.key].subresource_names
    is_manual_connection           = var.subnets[each.key].is_manual_connection
  }
}
