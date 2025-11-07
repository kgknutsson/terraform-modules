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

    virtual_network_id = try(local.env_config.virtual_network.virtual_network_id, var.config.global.virtual_network.virtual_network_id, null)
    address_space      = try(local.env_config.virtual_network.virtual_network_id, var.config.global.virtual_network.virtual_network_id, null) == null ? try([local.env_config.virtual_network.address_space], [var.config.global.virtual_network.address_space], []) : []

    nat_gateway = try(one([for i in merge(try(local.env_config.virtual_network.nat_gateway, {}), try(var.config.global.virtual_network.nat_gateway, {}))[*] : merge(
      {
        sku_name                    = null
        public_ip_allocation_method = "Static"
        zones                       = null
        virtual_network_subnet_id   = null
      },
      i
    ) if try(i.sku_name, null) != null]), null)

    virtual_network_peerings = { for k in setunion(keys(try(local.env_config.virtual_network.virtual_network_peerings, {})), keys(try(var.config.global.virtual_network.virtual_network_peerings, {}))) : k => {
      remote_virtual_network_id           = try(local.env_config.virtual_network.virtual_network_peerings[k].remote_virtual_network_id, var.config.global.virtual_network.virtual_network_peerings[k].remote_virtual_network_id, local.env_config.virtual_network.virtual_network_peerings[k], var.config.global.virtual_network.virtual_network_peerings[k])
      allow_virtual_network_access        = try(local.env_config.virtual_network.virtual_network_peerings[k].allow_virtual_network_access, var.config.global.virtual_network.virtual_network_peerings[k].allow_virtual_network_access, true)
      allow_forwarded_traffic             = try(local.env_config.virtual_network.virtual_network_peerings[k].allow_forwarded_traffic, var.config.global.virtual_network.virtual_network_peerings[k].allow_forwarded_traffic, false)
      remote_allow_virtual_network_access = try(local.env_config.virtual_network.virtual_network_peerings[k].remote_allow_virtual_network_access, var.config.global.virtual_network.virtual_network_peerings[k].remote_allow_virtual_network_access, true)
      remote_allow_forwarded_traffic      = try(local.env_config.virtual_network.virtual_network_peerings[k].remote_allow_forwarded_traffic, var.config.global.virtual_network.virtual_network_peerings[k].remote_allow_forwarded_traffic, false)
    } if try(local.env_config.virtual_network.virtual_network_id, var.config.global.virtual_network.virtual_network_id, local.env_config.virtual_network.address_space, var.config.global.virtual_network.address_space, null) != null }

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
    } if try(local.env_config.virtual_network.virtual_network_id, var.config.global.virtual_network.virtual_network_id, local.env_config.virtual_network.address_space, var.config.global.virtual_network.address_space, null) != null }

    private_dns_zones = merge(
      try(var.config.global.virtual_network.private_dns_zones, {}),
      try(local.env_config.virtual_network.private_dns_zones, {})
    )
  }

  subresource_dns_zone_map = yamldecode(file("${path.module}/private_endpoint_dns_zones.yml"))
  subresource_names        = flatten([for k, v in local.config.subnets : [for i in v.private_endpoints : i.subresource_names if try(i.private_dns_zone_group.private_dns_zone_ids, null) == null]])
  private_dns_zones        = flatten(values({ for k, v in local.subresource_dns_zone_map : k => v... if contains(local.subresource_names, k) }))
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

data "azurerm_virtual_network" "this" {
  count = length(local.config.virtual_network_id[*])

  name                = split("/", local.config.virtual_network_id)[8]
  resource_group_name = split("/", local.config.virtual_network_id)[4]
}

module "subnet_addrs" {
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"

  count = length(local.config.address_space)

  base_cidr_block = local.config.address_space.0
  networks        = [ for k, v in local.config.subnets : { name = k, new_bits = v.subnet_size - split("/", local.config.address_space.0)[1] } ]
}

resource "azurecaf_name" "subnet" {
  for_each = { for k, v in local.config.subnets : k => v if length(local.config.address_space) > 0 }

  name          = each.key
  resource_type = "azurerm_subnet"
}

resource "azurerm_subnet" "this" {
  for_each = { for k, v in local.config.subnets : k => v if length(local.config.address_space) > 0 }

  name                                          = azurecaf_name.subnet[each.key].result
  resource_group_name                           = local.config.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.this[0].name
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
    local.private_dns_zones
  )

  name                = each.key
  resource_group_name = local.config.resource_group_name
  tags                = local.config.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = merge([
    for k, v in azurerm_private_dns_zone.this : merge(
      length(local.config.address_space) > 0 ? {
        format("%s_%s-%s-%s", k, "vnet", local.config.name, var.environment) = {
          name                  = azurerm_virtual_network.this[0].name
          virtual_network_id    = azurerm_virtual_network.this[0].id
          private_dns_zone_name = k
          registration_enabled  = null
          resolution_policy     = null
        }
      } : local.config.virtual_network_id != null ? {
        join("_", [k, provider::azurerm::parse_resource_id(local.config.virtual_network_id).resource_name]) = {
          name                  = provider::azurerm::parse_resource_id(local.config.virtual_network_id).resource_name
          virtual_network_id    = local.config.virtual_network_id
          private_dns_zone_name = k
          registration_enabled  = null
          resolution_policy     = null
        }
      } : {},
      {
        for i in try(local.config.private_dns_zones[k].virtual_network_links, []) : join("_", [k, provider::azurerm::parse_resource_id(try(i.id, i)).resource_name]) => {
          name                  = provider::azurerm::parse_resource_id(try(i.id, i)).resource_name
          virtual_network_id    = try(i.id, i)
          private_dns_zone_name = k
          registration_enabled  = try(i.registration_enabled, null)
          resolution_policy     = try(i.resolution_policy, null)
        }
      }
    )
  ]...)

  name                  = each.value.name
  resource_group_name   = local.config.resource_group_name
  virtual_network_id    = each.value.virtual_network_id
  private_dns_zone_name = each.value.private_dns_zone_name
  registration_enabled  = each.value.registration_enabled
  resolution_policy     = each.value.resolution_policy
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
  location            = local.config.location
  resource_group_name = local.config.resource_group_name
  subnet_id           = try(azurerm_subnet.this[each.value.subnet_key].id, join("/", [local.config.virtual_network_id, "subnets", contains(data.azurerm_virtual_network.this[0].subnets, each.value.subnet_key) ? each.value.subnet_key : join("-", ["snet", each.value.subnet_key])]))
  tags                = local.config.tags

  private_dns_zone_group {
    name                 = try(each.value.private_dns_zone_group.name, each.value.private_dns_zone_group, "default")
    private_dns_zone_ids = try([for i in each.value.private_dns_zone_group.private_dns_zone_ids : try(azurerm_private_dns_zone.this[i].id, i)], compact(flatten([for k, v in local.subresource_dns_zone_map : [for i in flatten([v]) : try(azurerm_private_dns_zone.this[i].id, null)] if contains(flatten([each.value.subresource_names]), k)])))
  }

  private_service_connection {
    name                           = azurecaf_name.private_endpoint[each.key].result
    private_connection_resource_id = each.value.private_connection_resource_id
    subresource_names              = flatten([each.value.subresource_names])
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

  input = try(azurerm_subnet.this[each.value].address_prefixes, null)
}

resource "azurerm_private_dns_a_record" "this" {
  for_each = merge(flatten([
    for k, v in local.config.subnets : [
      for i in v.private_endpoints: {
        for ii in setproduct(i.private_dns_zone_group.private_dns_zone_ids, i.private_dns_a_record_names) : join("_", ii) => {
          zone_name = ii[0]
          name      = ii[1]
          records   = [azurerm_private_endpoint.this[try(i.name, regex(".+/(.+)", i.private_connection_resource_id)[0])].private_service_connection[0].private_ip_address]
        }
      } if length(try(i.private_dns_zone_group.private_dns_zone_ids, [])) > 0 && length(try(i.private_dns_a_record_names, [])) > 0
    ] if length(v.private_endpoints) > 0
  ])...)

  name                = each.value.name
  resource_group_name = local.config.resource_group_name
  records             = each.value.records
  ttl                 = 300
  zone_name           = each.value.zone_name
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
  location            = local.config.location
  resource_group_name = local.config.resource_group_name
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

resource "azurecaf_name" "nat_gateway" {
  count = length(local.config.nat_gateway[*])

  name          = local.config.name
  resource_type = "general"
  prefixes      = ["ng"]
  suffixes      = [var.environment]
  
}

resource "azurerm_nat_gateway" "this" {
  count = length(local.config.nat_gateway[*])

  name                = azurecaf_name.nat_gateway[0].result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  sku_name            = local.config.nat_gateway.sku_name
  zones               = local.config.nat_gateway.zones
  tags                = local.config.tags
}

resource "azurecaf_name" "public_ip" {
  count = length(local.config.nat_gateway[*])

  name          = local.config.name
  resource_type = "azurerm_public_ip"
  suffixes      = [var.environment]
}

resource "azurerm_public_ip" "this" {
  count = length(local.config.nat_gateway[*])

  name                = azurecaf_name.public_ip[0].result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  allocation_method   = local.config.nat_gateway.public_ip_allocation_method
  zones               = local.config.nat_gateway.zones
  tags                = local.config.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count = length(local.config.nat_gateway[*])

  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.this[0].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  count = length(try(local.config.nat_gateway.virtual_network_subnet_id[*], []))

  subnet_id      = try(azurerm_subnet.this[local.config.nat_gateway.virtual_network_subnet_id].id, local.config.nat_gateway.virtual_network_subnet_id)
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}

data "azurerm_virtual_network" "that" {
  for_each = local.config.virtual_network_peerings

  name                = provider::azurerm::parse_resource_id(each.value.remote_virtual_network_id).resource_name
  resource_group_name = provider::azurerm::parse_resource_id(each.value.remote_virtual_network_id).resource_group_name
}

resource "azurerm_virtual_network_peering" "this" {
  for_each = local.config.virtual_network_peerings

  name                         = each.key
  resource_group_name          = local.config.resource_group_name
  virtual_network_name         = azurerm_virtual_network.this[0].name
  remote_virtual_network_id    = each.value.remote_virtual_network_id
  allow_virtual_network_access = each.value.allow_virtual_network_access
  allow_forwarded_traffic      = each.value.allow_forwarded_traffic

  triggers = {
    remote_address_space = join(",", data.azurerm_virtual_network.that[each.key].address_space)
  }
}

resource "azurerm_virtual_network_peering" "that" {
  for_each = local.config.virtual_network_peerings

  name                         = azurerm_virtual_network.this[0].name
  resource_group_name          = data.azurerm_virtual_network.that[each.key].resource_group_name
  virtual_network_name         = data.azurerm_virtual_network.that[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.this[0].id
  allow_virtual_network_access = each.value.remote_allow_virtual_network_access
  allow_forwarded_traffic      = each.value.remote_allow_forwarded_traffic

  triggers = {
    remote_address_space = join(",", azurerm_virtual_network.this[0].address_space)
  }
}
