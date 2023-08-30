locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name                = var.config.global.name
    location            = var.config.global.location
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
      try(var.config.global.virtual_wan.tags, {}),
      try(local.env_config.virtual_wan.tags, {})
    )

    naming = {
      for i in [ "azurerm_virtual_wan", "azurerm_virtual_hub", "azurerm_vpn_gateway", "azurerm_vpn_site" ] : i => merge(
        {
          name          = var.config.global.name
          suffixes      = compact([var.environment])
          random_length = null
        },
        try(lookup(var.config.virtual_wan.naming, i), {}),
        try(lookup(local.env_config.virtual_wan.naming, i), {})
      )
    }

    type               = try(local.env_config.virtual_wan.type, var.config.global.virtual_wan.type, null)
    virtual_hubs       = merge(try(var.config.global.virtual_wan.virtual_hubs, {}), try(local.env_config.virtual_wan.virtual_hubs, {}))
  }
}

resource "azurecaf_name" "virtual_wan" {
  count = length(local.config.type[*])

  resource_type = "azurerm_virtual_wan"
  name          = local.config.naming["azurerm_virtual_wan"].name
  suffixes      = local.config.naming["azurerm_virtual_wan"].suffixes
  random_length = local.config.naming["azurerm_virtual_wan"].random_length
}

resource "azurerm_virtual_wan" "this" {
  count = length(azurecaf_name.virtual_wan)

  name                = azurecaf_name.virtual_wan.0.result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  tags                = local.config.tags
  type                = local.config.type
}

resource "azurecaf_name" "virtual_hub" {
  for_each = { for k, v in local.config.virtual_hubs : k => v if local.config.type != null }

  resource_type = "azurerm_virtual_hub"
  name          = local.config.naming["azurerm_virtual_hub"].name
  suffixes      = concat([each.key], local.config.naming["azurerm_virtual_hub"].suffixes)
  random_length = local.config.naming["azurerm_virtual_hub"].random_length
}

resource "azurerm_virtual_hub" "this" {
  for_each = { for k, v in local.config.virtual_hubs : k => v if local.config.type != null }

  name                = azurecaf_name.virtual_hub[each.key].result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  tags                = local.config.tags
  virtual_wan_id      = azurerm_virtual_wan.this.0.id
  sku                 = each.value.sku
  address_prefix      = each.value.address_prefix
}

resource "azurecaf_name" "vpn_gateway" {
  for_each = azurecaf_name.virtual_hub

  resource_type = "general"
  name          = local.config.naming["azurerm_vpn_gateway"].name
  prefixes      = ["vpng"]
  suffixes      = concat([each.key], local.config.naming["azurerm_vpn_gateway"].suffixes)
  random_length = local.config.naming["azurerm_vpn_gateway"].random_length
}

resource "azurerm_vpn_gateway" "this" {
  for_each = azurecaf_name.vpn_gateway

  name                = each.value.result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  virtual_hub_id      = azurerm_virtual_hub.this[each.key].id
  routing_preference  = try(local.config.virtual_hubs[each.key].routing_preference, null)
  scale_unit          = try(local.config.virtual_hubs[each.key].scale_unit, null)
  tags                = local.config.tags
}

resource "azurecaf_name" "vpn_site" {
  for_each = merge([
    for k, v in local.config.virtual_hubs : {
      for x, y in v.vpn_sites : join("_", [k, x]) => y
    } if local.config.type != null
  ]...) 

  name          = local.config.naming["azurerm_vpn_site"].name
  resource_type = "azurerm_vpn_site"
  suffixes      = concat(split("_", each.key), local.config.naming["azurerm_vpn_site"].suffixes)
  random_length = local.config.naming["azurerm_vpn_site"].random_length
}

resource "azurerm_vpn_site" "this" {
  for_each = merge([
    for k, v in local.config.virtual_hubs : {
      for x, y in v.vpn_sites : join("_", [k, x]) => y
    } if local.config.type != null
  ]...) 

  name                = azurecaf_name.vpn_site[each.key].result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  tags                = local.config.tags
  virtual_wan_id      = azurerm_virtual_wan.this.0.id
  device_vendor       = try(each.value.device_vendor, null)
  address_cidrs       = try(each.value.address_cidrs, null)

  dynamic "link" {
    for_each = each.value.links

    content {
      name       = link.key
      fqdn       = try(link.value.fqdn, null)
      ip_address = try(link.value.ip_address, null)
    }
  }
}

resource "azurecaf_name" "vpn_gateway_connection" {
  for_each = merge([
    for k, v in local.config.virtual_hubs : {
      for x, y in v.vpn_sites : join("_", [k, x]) => y
    } if local.config.type != null
  ]...) 

  name          = local.config.naming["azurerm_vpn_site"].name
  resource_type = "azurerm_vpn_gateway_connection"
  suffixes      = concat(split("_", each.key), local.config.naming["azurerm_vpn_site"].suffixes)
  random_length = local.config.naming["azurerm_vpn_site"].random_length
}

resource "azurerm_vpn_gateway_connection" "this" {
  for_each = merge([
    for k, v in local.config.virtual_hubs : {
      for x, y in v.vpn_sites : join("_", [k, x]) => y
    } if local.config.type != null
  ]...) 

  name               = azurecaf_name.vpn_gateway_connection[each.key].result
  vpn_gateway_id     = azurerm_vpn_gateway.this[split("_", each.key).0].id
  remote_vpn_site_id = azurerm_vpn_site.this[each.key].id

  dynamic "vpn_link" {
    for_each = azurerm_vpn_site.this[each.key].link

    content {
      name             = vpn_link.value.name
      vpn_site_link_id = vpn_link.value.id
    }
  }

  lifecycle {
    ignore_changes = [ vpn_link.0.shared_key ]
  }
}
