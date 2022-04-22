locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name           = var.config.global.name
    location       = var.config.global.location

    tags = merge({
      application       = var.config.global.name
      environment       = var.environment
      terraform         = "true"
    }, var.tags)

    address_space = try([local.env_config.virtual_network.address_space], [var.config.global.virtual_network.address_space], [])

    subnets = { for k, v in merge(try(local.env_config.virtual_network.subnets, {}), try(var.config.global.virtual_network.subnets, {})) : k => merge({
      service_endpoints              = null
      service_delegation             = null
      private_connection_resource_id = null
      subresource_names              = null
      is_manual_connection           = try(v.private_connection_resource_id, null) != null ? false : null
    }, v) if can(coalesce(try(v.service_endpoints.0, null), try(v.service_delegation, null), try(v.private_connection_resource_id, null))) }
  }
}

resource "azurecaf_name" "virtual_network" {
  count = length(local.config.address_space)

  name          = local.config.name
  resource_type = "azurerm_virtual_network"
  suffixes      = [var.environment]
}

resource "azurerm_virtual_network" "this" {
  count = length(local.config.address_space)

  name                = azurecaf_name.virtual_network.0.result
  resource_group_name = var.resource_group
  location            = local.config.location
  tags                = local.config.tags
  address_space       = local.config.address_space
}

resource "azurecaf_name" "subnet" {
  for_each = { for k, v in local.config.subnets : k => v if can(azurerm_virtual_network.this.0) }

  name          = each.key
  resource_type = "azurerm_subnet"
}

resource "azurerm_subnet" "this" {
  for_each = azurecaf_name.subnet

  name                 = each.value.result
  resource_group_name  = azurerm_virtual_network.this.0.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.0.name
  address_prefixes     = [ for s in azurerm_virtual_network.this.0.address_space : cidrsubnet(s, 4, index(keys(azurecaf_name.subnet), each.key)) ]
  service_endpoints    = local.config.subnets[each.key].service_endpoints

  dynamic "delegation" {
    for_each = local.config.subnets[each.key].service_delegation[*]

    content {
      name = "delegation"

      service_delegation {
        name    = delegation.value
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }

  enforce_private_link_endpoint_network_policies = local.config.subnets[each.key].private_connection_resource_id != null
}

resource "azurerm_private_dns_zone" "this" {
  count = anytrue(values(azurerm_subnet.this)[*].enforce_private_link_endpoint_network_policies) ? 1 : 0

  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_virtual_network.this.0.resource_group_name
  tags                = local.config.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count = length(azurerm_private_dns_zone.this)

  name                  = azurerm_virtual_network.this.0.name
  resource_group_name   = azurerm_virtual_network.this.0.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.0.name
  virtual_network_id    = azurerm_virtual_network.this.0.id
  tags                  = local.config.tags
}

resource "azurecaf_name" "private_endpoint" {
  for_each = { for k, v in azurerm_subnet.this : k => v if v.enforce_private_link_endpoint_network_policies }

  name          = reverse(split("/", local.config.subnets[each.key].private_connection_resource_id))[0]
  resource_type = "azurerm_private_endpoint"
  suffixes      = [local.config.name]
}

resource "azurerm_private_endpoint" "this" {
  for_each = azurecaf_name.private_endpoint

  name                = each.value.result
  location            = azurerm_virtual_network.this.0.location
  resource_group_name = azurerm_virtual_network.this.0.resource_group_name
  subnet_id           = azurerm_subnet.this[each.key].id
  tags                = local.config.tags

  private_dns_zone_group {
    name                 = replace(azurerm_private_dns_zone.this.0.name, ".", "-")
    private_dns_zone_ids = azurerm_private_dns_zone.this[*].id
  }

  private_service_connection {
    name                           = each.value.result
    private_connection_resource_id = local.config.subnets[each.key].private_connection_resource_id
    subresource_names              = local.config.subnets[each.key].subresource_names
    is_manual_connection           = local.config.subnets[each.key].is_manual_connection
  }
}
