moved {
  from = azurerm_private_dns_zone.this.0
  to   = azurerm_private_dns_zone.this["privatelink.database.windows.net"]
}

moved {
  from = azurerm_private_dns_zone_virtual_network_link.this.0
  to   = azurerm_private_dns_zone_virtual_network_link.this["privatelink.database.windows.net"]
}

locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name                = var.config.global.name
    location            = var.resource_group.location
    resource_group_name = var.resource_group.name

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

    subnets = { for k in setunion(keys(try(local.env_config.virtual_network.subnets, {})), keys(try(var.config.global.virtual_network.subnets, {}))) : k => {
      subnet_size                    = try(local.env_config.virtual_network.subnets[k].subnet_size, var.config.global.virtual_network.subnets[k].subnet_size, 28)
      service_endpoints              = concat(try(local.env_config.virtual_network.subnets[k].service_endpoints, []), try(var.config.global.virtual_network.subnets[k].service_endpoints, []))
      service_delegation             = try(local.env_config.virtual_network.subnets[k].service_delegation, var.config.global.virtual_network.subnets[k].service_delegation, null)
      private_connection_resource_id = try(local.env_config.virtual_network.subnets[k].private_connection_resource_id, var.config.global.virtual_network.subnets[k].private_connection_resource_id, null)
      subresource_names              = try(local.env_config.virtual_network.subnets[k].subresource_names, var.config.global.virtual_network.subnets[k].subresource_names, null)
      is_manual_connection           = try(local.env_config.virtual_network.subnets[k].is_manual_connection, var.config.global.virtual_network.subnets[k].is_manual_connection, false)
      security_group_rules           = try(local.env_config.virtual_network.subnets[k].security_group_rules, var.config.global.virtual_network.subnets[k].security_group_rules, [])
    } if can(try(local.env_config.virtual_network.address_space, var.config.global.virtual_network.address_space)) }
  }

  subresource_dns_zone_map = {
    sqlServer = "privatelink.database.windows.net"
    vault     = "privatelink.vaultcore.azure.net"
  }

  subnet_dns_zone_map = {
    for k, v in local.config.subnets : k => local.subresource_dns_zone_map[v.subresource_names.0] if local.config.subnets[k].private_connection_resource_id != null
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
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  tags                = local.config.tags
  address_space       = local.config.address_space
}

module "subnet_addrs" {
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"

  count = length(local.config.address_space)

  base_cidr_block = local.config.address_space.0
  networks        = [ for k, v in local.config.subnets : { name = k, new_bits = v.subnet_size - split("/", local.config.address_space.0)[1] } ]
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
  address_prefixes     = [ module.subnet_addrs.0.network_cidr_blocks[each.key] ]
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
  for_each = toset([ for k, v in local.subresource_dns_zone_map : v if contains(flatten(values(local.config.subnets)[*].subresource_names), k) ])

  name                = each.key
  resource_group_name = azurerm_virtual_network.this.0.resource_group_name
  tags                = local.config.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = azurerm_private_dns_zone.this

  name                  = azurerm_virtual_network.this.0.name
  resource_group_name   = azurerm_virtual_network.this.0.resource_group_name
  private_dns_zone_name = each.key
  virtual_network_id    = azurerm_virtual_network.this.0.id
  tags                  = local.config.tags
}

resource "azurecaf_name" "private_endpoint" {
  for_each = { for k, v in local.config.subnets : k => v if v.private_connection_resource_id != null }

  name          = reverse(split("/", each.value.private_connection_resource_id))[0]
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
    name                 = replace(azurerm_private_dns_zone.this[local.subnet_dns_zone_map[each.key]].name, ".", "-")
    private_dns_zone_ids = [azurerm_private_dns_zone.this[local.subnet_dns_zone_map[each.key]].id]
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
