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
      try(var.config.global.relay.tags, {}),
      try(local.env_config.relay.tags, {})
    )

    naming = {
      for i in [
        "azurerm_relay_namespace",
      ] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = compact([var.environment])
          random_length = null
          use_slug      = null
        },
        try(lookup(var.config.global.relay.naming, i), {}),
        try(lookup(local.env_config.relay.naming, i), {})
      )
    }

    namespaces = {
      for k in setunion(
        try(keys(local.env_config.relay.namespaces), []),
        try(keys(var.config.global.relay.namespaces), [])
      ) : k => merge(
        {
          sku_name            = "Standard"
          authorization_rules = {}
          hybrid_connections  = {}
        },
        try(local.env_config.relay.namespaces[k], {}),
        try(var.config.global.relay.namespaces[k], {}),
      )
    }

    hybrid_connection_authorization_rules = {}
  }
}

resource "azurecaf_name" "relay_namespace" {
  for_each = local.config.namespaces

  name           = local.config.naming["azurerm_relay_namespace"].name
  resource_type = "azurerm_relay_namespace"
  prefixes       = local.config.naming["azurerm_relay_namespace"].prefixes
  suffixes       = concat(local.config.naming["azurerm_relay_namespace"].suffixes, [each.key])
  random_length  = local.config.naming["azurerm_relay_namespace"].random_length
  use_slug       = local.config.naming["azurerm_relay_namespace"].use_slug
}

resource "azurerm_relay_namespace" "this" {
  for_each = local.config.namespaces

  name                = azurecaf_name.relay_namespace[each.key].result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  tags                = local.config.tags
  sku_name            = each.value.sku_name
}

resource "azurerm_relay_namespace_authorization_rule" "this" {
  for_each = merge([
    for k, v in azurerm_relay_namespace.this : {
      for x, y in local.config.namespaces[k].authorization_rules : join("-", [k, x]) => merge(
        {
          name           = x
          namespace_name = v.name
          listen         = false
          send           = false
          manage         = false
        },
        { for i in y : i => true }
      )
    }
  ]...)

  name                = each.value.name
  resource_group_name = local.config.resource_group_name
  namespace_name      = each.value.namespace_name
  listen              = each.value.manage || each.value.listen
  send                = each.value.manage || each.value.send
  manage              = each.value.manage
}

resource "azurerm_relay_hybrid_connection" "this" {
  for_each = merge([
    for k, v in azurerm_relay_namespace.this : {
      for x, y in local.config.namespaces[k].hybrid_connections : join("-", [k, x]) => {
        name                          = x
        relay_namespace_name          = v.name
        requires_client_authorization = null

        user_metadata = try(
          jsonencode([ for k, v in y.user_metadata : { key = k , value = v } ]),
          null
        )
      }
    }
  ]...)

  name                          = each.value.name
  relay_namespace_name          = each.value.relay_namespace_name
  resource_group_name           = local.config.resource_group_name
  requires_client_authorization = each.value.requires_client_authorization
  user_metadata                 = each.value.user_metadata
}

resource "azurerm_relay_hybrid_connection_authorization_rule" "this" {
  for_each = merge(flatten([
    for k, v in azurerm_relay_namespace.this : [
      for x, y in local.config.namespaces[k].hybrid_connections : {
        for i, j in try(y.authorization_rules, {}) : join("-", [k, x, i]) => merge(
          {
            name                   = i
            namespace_name         = azurerm_relay_namespace.this[k].name
            hybrid_connection_name = azurerm_relay_hybrid_connection.this[join("-", [k, x])].name
            listen                 = false
            send                   = false
            manage                 = false
          },
          { for o in j : o => true }
        )
      }
    ]
  ])...)

  name                   = each.value.name
  resource_group_name    = local.config.resource_group_name
  namespace_name         = each.value.namespace_name
  hybrid_connection_name = each.value.hybrid_connection_name
  listen                 = each.value.manage || each.value.listen
  send                   = each.value.manage || each.value.send
  manage                 = each.value.manage
}
