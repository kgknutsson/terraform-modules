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
      subnet_size                                   = try(local.env_config.virtual_network.subnets[k].subnet_size, var.config.global.virtual_network.subnets[k].subnet_size, 28)
      private_endpoint_network_policies             = try(local.env_config.virtual_network.subnets[k].private_endpoint_network_policies, var.config.global.virtual_network.subnets[k].private_endpoint_network_policies, null)
      private_link_service_network_policies_enabled = try(local.env_config.virtual_network.subnets[k].private_link_service_network_policies_enabled, var.config.global.virtual_network.subnets[k].private_link_service_network_policies_enabled, null)
      security_group_rules                          = try(local.env_config.virtual_network.subnets[k].security_group_rules, var.config.global.virtual_network.subnets[k].security_group_rules, [])
      service_endpoints                             = concat(try(local.env_config.virtual_network.subnets[k].service_endpoints, []), try(var.config.global.virtual_network.subnets[k].service_endpoints, []))
      service_delegation                            = try(local.env_config.virtual_network.subnets[k].service_delegation, var.config.global.virtual_network.subnets[k].service_delegation, null)

      private_endpoints = concat(
        try(local.env_config.virtual_network.subnets[k].private_endpoints, []),
        try(var.config.global.virtual_network.subnets[k].private_endpoints, []),
        try([{
          name                           = k
          private_connection_resource_id = try(local.env_config.virtual_network.subnets[k].private_connection_resource_id, var.config.global.virtual_network.subnets[k].private_connection_resource_id)
          subresource_names              = try(local.env_config.virtual_network.subnets[k].subresource_names, var.config.global.virtual_network.subnets[k].subresource_names)
          is_manual_connection           = try(local.env_config.virtual_network.subnets[k].is_manual_connection, var.config.global.virtual_network.subnets[k].is_manual_connection, false)
        }], [])
      )
    } if can(try(local.env_config.virtual_network.address_space, var.config.global.virtual_network.address_space)) }

    private_dns_zones = merge(
      try(var.config.global.virtual_network.private_dns_zones, {}),
      try(local.env_config.virtual_network.private_dns_zones, {})
    )
  }

  subresource_dns_zone_map = yamldecode(file("${path.module}/private_endpoint_dns_zones.yml"))
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
  for_each = local.config.subnets

  name                                          = azurecaf_name.subnet[each.key].result
  resource_group_name                           = azurerm_virtual_network.this.0.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.this.0.name
  address_prefixes                              = [ module.subnet_addrs.0.network_cidr_blocks[each.key] ]
  private_endpoint_network_policies             = each.value.private_endpoint_network_policies
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled
  service_endpoints                             = each.value.service_endpoints

  dynamic "delegation" {
    for_each = local.config.subnets[each.key].service_delegation[*]

    content {
      name = replace(try(delegation.value.name, delegation.value), "/", ".")

      service_delegation {
        name    = try(delegation.value.name, delegation.value)
        actions = try(delegation.value.actions, ["Microsoft.Network/virtualNetworks/subnets/action"])
      }
    }
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each = setunion(
    keys(local.config.private_dns_zones),
    matchkeys(
      values(local.subresource_dns_zone_map),
      keys(local.subresource_dns_zone_map),
      flatten([ for k, v in local.config.subnets : v.private_endpoints[*].subresource_names ])
    )
    )

  name                = each.key
  resource_group_name = azurerm_virtual_network.this.0.resource_group_name
  tags                = local.config.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = azurerm_private_dns_zone.this

  name                  = azurerm_virtual_network.this.0.name
  resource_group_name   = azurerm_virtual_network.this.0.resource_group_name
  virtual_network_id    = azurerm_virtual_network.this.0.id
  private_dns_zone_name = each.key
  registration_enabled  = try(local.config.private_dns_zones[each.key].registration_enabled, null)
  tags                  = local.config.tags
}

resource "azurecaf_name" "private_endpoint" {
  for_each = merge([ for k, v in local.config.subnets : {
    for i in v.private_endpoints : try(i.name, regex(".+/(.+)", i.private_connection_resource_id)[0]) => regex(".+/(.+)", i.private_connection_resource_id)[0]
  } if length(v.private_endpoints) > 0 ]...)
  
  name          = each.value
  resource_type = "azurerm_private_endpoint"
  suffixes      = each.key != each.value ? [each.key, local.config.name] : [local.config.name]
}

resource "azurerm_private_endpoint" "this" {
  for_each = merge([ for k, v in local.config.subnets : {
    for i in v.private_endpoints : try(i.name, regex(".+/(.+)", i.private_connection_resource_id)[0]) => merge({ subnet_key = k, is_manual_connection = false }, i)
  } if length(v.private_endpoints) > 0 ]...)

  name                = azurecaf_name.private_endpoint[each.key].result
  location            = azurerm_virtual_network.this.0.location
  resource_group_name = azurerm_virtual_network.this.0.resource_group_name
  subnet_id           = azurerm_subnet.this[each.value.subnet_key].id
  tags                = local.config.tags

  private_dns_zone_group {
    name                 = try(each.value.private_dns_zone_group.name, each.value.private_dns_zone_group, "default")
    private_dns_zone_ids = try(each.value.private_dns_zone_group.private_dns_zone_ids, compact([ for i in each.value.subresource_names : try(azurerm_private_dns_zone.this[local.subresource_dns_zone_map[i]].id, null) ]))
  }

  private_service_connection {
    name                           = azurecaf_name.private_endpoint[each.key].result
    private_connection_resource_id = each.value.private_connection_resource_id
    subresource_names              = each.value.subresource_names
    is_manual_connection           = each.value.is_manual_connection
  }

  lifecycle {
    replace_triggered_by = [ terraform_data.private_endpoint_replacement_trigger[each.key] ]
  }
}

resource "terraform_data" "private_endpoint_replacement_trigger" {
  for_each = merge([ for k, v in local.config.subnets : {
    for i in v.private_endpoints : try(i.name, regex(".+/(.+)", i.private_connection_resource_id)[0]) => k
  } if length(v.private_endpoints) > 0 ]...)

  input = azurerm_subnet.this[each.value].address_prefixes
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
