locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name     = var.config.global.name
    location = var.config.global.location

    tags = merge(
      {
        application = var.config.global.name
        environment = var.environment
        terraform   = "true"
      },
      var.tags,
      try(var.config.global.tags, {}),
      try(local.env_config.tags, {}),
      try(var.config.global.virtual_network.tags, {}),
      try(local.env_config.virtual_network.tags, {})
    )

    address_space = try([local.env_config.virtual_network.address_space], [var.config.global.virtual_network.address_space], [])

    subnets = { for k, v in merge(try(local.env_config.virtual_network.subnets, {}), try(var.config.global.virtual_network.subnets, {})) : k => {
      service_endpoints              = try(v.service_endpoints, null)
      service_delegation             = try(v.service_delegation, null)
      private_connection_resource_id = try(v.private_connection_resource_id, null)
      subresource_names              = try(v.subresource_names, null)
      is_manual_connection           = can(try(v.private_connection_resource_id)) ? false : null
      security_group_rules           = try(v.security_group_rules, [])
    } if can(try(local.env_config.virtual_network.address_space, var.config.global.virtual_network.address_space)) }
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
  for_each = local.config.subnets

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

  private_endpoint_network_policies_enabled = local.config.subnets[each.key].private_connection_resource_id == null
}

resource "azurerm_private_dns_zone" "this" {
  count = alltrue(values(azurerm_subnet.this)[*].private_endpoint_network_policies_enabled) ? 0 : 1

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
  for_each = { for k, v in azurerm_subnet.this : k => v if !v.private_endpoint_network_policies_enabled }

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

resource "azurecaf_name" "network_security_group" {
  for_each = { for k, v in local.config.subnets : k => v if length(v.security_group_rules) > 0 }

  name          = local.config.name
  resource_type = "azurerm_network_security_group"
  suffixes      = [each.key, var.environment]
}

resource "azurerm_network_security_group" "this" {
  for_each = azurecaf_name.network_security_group

  name                = each.value.result
  location            = azurerm_virtual_network.this.0.location
  resource_group_name = azurerm_virtual_network.this.0.resource_group_name
  tags                = local.config.tags

  dynamic "security_rule" {
    for_each = [ for i, v in local.config.subnets[each.key].security_group_rules : merge({ priority: i * 10 + 100 }, v) ]

    content {
      name                         = security_rule.value.name
      description                  = try(security_rule.value.description, "")
      priority                     = security_rule.value.priority
      direction                    = security_rule.value.direction
      access                       = security_rule.value.access
      protocol                     = security_rule.value.protocol
      source_port_range            = try(security_rule.value.source_port_range, length(try(security_rule.value.source_port_ranges, [])) == 0 ? "*" : null)
      source_port_ranges           = try(security_rule.value.source_port_ranges, null)
      destination_port_range       = try(security_rule.value.destination_port_range, length(try(security_rule.value.destination_port_ranges, [])) == 0 ? "*" : null)
      destination_port_ranges      = try(security_rule.value.destination_port_ranges, null)
      source_address_prefix        = try(security_rule.value.source_address_prefix, length(try(security_rule.value.source_address_prefixes, [])) == 0 ? "*" : null)
      source_address_prefixes      = try(security_rule.value.source_address_prefixes, null)
      destination_address_prefix   = try(security_rule.value.destination_address_prefix, length(try(security_rule.value.destination_address_prefixes, [])) == 0 ? "*" : null)
      destination_address_prefixes = try(security_rule.value.destination_address_prefixes, null)
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = azurerm_network_security_group.this

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = each.value.id
}
