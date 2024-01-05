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
      try(var.config.global.private_dns_resolver.tags, {}),
      try(local.env_config.private_dns_resolver.tags, {})
    )

    virtual_network_id          = var.virtual_network.id
    inbound_endpoint_subnet_id  = try(var.virtual_network.subnet_id_map[try(local.env_config.private_dns_resolver.inbound_endpoint.subnet_id, var.config.global.private_dns_resolver.inbound_endpoint.subnet_id)], null)
    outbound_endpoint_subnet_id = try(var.virtual_network.subnet_id_map[try(local.env_config.private_dns_resolver.outbound_endpoint.subnet_id, var.config.global.private_dns_resolver.outbound_endpoint.subnet_id)], null)

    forwarding_rules = merge(
      try(var.config.global.private_dns_resolver.forwarding_rules, {}),
      try(local.env_config.private_dns_resolver.forwarding_rules, {})
    )
  }
}

resource "azurerm_private_dns_resolver" "this" {
  count = length(local.config.virtual_network_id[*])

  name                = "dns-private-resolver"
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  virtual_network_id  = local.config.virtual_network_id
  tags                = local.config.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "this" {
  count = length(azurerm_private_dns_resolver.this)

  name                    = "InboundEndpoint"
  private_dns_resolver_id = azurerm_private_dns_resolver.this[0].id
  location                = local.config.location
  tags                    = local.config.tags

  ip_configurations {
    subnet_id = local.config.inbound_endpoint_subnet_id
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "this" {
  count = length(azurerm_private_dns_resolver.this)

  name                    = "OutboundEndpoint"
  private_dns_resolver_id = azurerm_private_dns_resolver.this[0].id
  location                = local.config.location
  tags                    = local.config.tags
  subnet_id               = local.config.outbound_endpoint_subnet_id
  }

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "this" {
  count = length(azurerm_private_dns_resolver_outbound_endpoint.this)

  name                                       = "dns-forwarding-ruleset"
  resource_group_name                        = local.config.resource_group_name
  location                                   = local.config.location
  tags                                       = local.config.tags
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.this[0].id]
}

resource "azurerm_private_dns_resolver_forwarding_rule" "this" {
  for_each = { for k, v in local.config.forwarding_rules : k => v if length(azurerm_private_dns_resolver_dns_forwarding_ruleset.this) > 0 }

  name                      = each.key
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this[0].id
  domain_name               = each.value.domain_name
  enabled                   = true

  dynamic "target_dns_servers" {
    for_each = each.value.target_dns_servers

    content {
      ip_address = try(target_dns_servers.value.ip, target_dns_servers.value)
      port       = try(target_dns_servers.value.port, 53)
    }
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "this" {
  count = min(length(local.config.virtual_network_id[*]), length(azurerm_private_dns_resolver_dns_forwarding_ruleset.this))

  name                      = "vnet-corehub-link"
  virtual_network_id        = local.config.virtual_network_id
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.this[0].id
}
