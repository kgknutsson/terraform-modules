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
      try(var.config.global.servicebus.tags, {}),
      try(local.env_config.servicebus.tags, {})
    )

    naming = {
      for i in [
        "azurerm_servicebus_namespace",
      ] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = compact([var.environment])
          random_length = null
          use_slug      = null
        },
        try(lookup(var.config.global.servicebus.naming, i), {}),
        try(lookup(local.env_config.servicebus.naming, i), {})
      )
    }

    sku      = try(local.env_config.servicebus.sku, var.config.global.servicebus.sku, null) // Basic, Standard or Premium
    capacity = try(local.env_config.servicebus.capacity, var.config.global.servicebus.capacity, 0)

    authorization_rules = {
      for k in setunion(
        try(keys(local.env_config.servicebus.authorization_rules), []),
        try(keys(var.config.global.servicebus.authorization_rules), [])
      ) : k => merge(
        {
          listen = false
          send   = false
          manage = false
        },
        try({ for i in local.env_config.servicebus.authorization_rules[k] : i => true }, {}),
        try({ for i in var.config.global.servicebus.authorization_rules[k] : i => true }, {})
      )
    }

    queues = {
      for k in setunion(
        try(keys(local.env_config.servicebus.queues), []),
        try(keys(var.config.global.servicebus.queues), [])
      ) : k => merge(
        {},
        try(local.env_config.servicebus.queues[k], {}),
        try(var.config.global.servicebus.queues[k], {}),
        {
          authorization_rules = {
            for i in setunion(
              try(keys(local.env_config.servicebus.queues[k].authorization_rules), []),
              try(keys(var.config.global.servicebus.queues[k].authorization_rules), [])
            ) : join("-", [k, i]) => merge(
              {
                name   = i
                listen = false
                send   = false
                manage = false
              },
              {
                for i in try(
                  coalescelist(
                    try(local.env_config.servicebus.queues[k].authorization_rules[i], []),
                    try(var.config.global.servicebus.queues[k].authorization_rules[i], [])
                  ),
                  []
                ) : i => true
              }
            )
          }
        }
      )
    }

    topics = {
      for k in setunion(
        try(keys(local.env_config.servicebus.topics), []),
        try(keys(var.config.global.servicebus.topics), [])
      ) : k => merge(
        {},
        try(local.env_config.servicebus.topics[k], {}),
        try(var.config.global.servicebus.topics[k], {}),
        {
          authorization_rules = {
            for i in setunion(
              try(keys(local.env_config.servicebus.topics[k].authorization_rules), []),
              try(keys(var.config.global.servicebus.topics[k].authorization_rules), [])
            ) : join("-", [k, i]) => merge(
              {
                name   = i
                listen = false
                send   = false
                manage = false
              },
              {
                for i in try(
                  coalescelist(
                    try(local.env_config.servicebus.topics[k].authorization_rules[i], []),
                    try(var.config.global.servicebus.topics[k].authorization_rules[i], [])
                  ),
                  []
                ) : i => true
              }
            )
          }
        }
      )
    }
  }
}

resource "azurecaf_name" "servicebus_namespace" {
  count = length(local.config.sku[*])

  name           = local.config.naming["azurerm_servicebus_namespace"].name
  resource_type = "azurerm_servicebus_namespace"
  prefixes       = local.config.naming["azurerm_servicebus_namespace"].prefixes
  suffixes       = local.config.naming["azurerm_servicebus_namespace"].suffixes
  random_length  = local.config.naming["azurerm_servicebus_namespace"].random_length
  use_slug       = local.config.naming["azurerm_servicebus_namespace"].use_slug
}

resource "azurerm_servicebus_namespace" "this" {
  count = length(azurecaf_name.servicebus_namespace)

  name                = azurecaf_name.servicebus_namespace[0].result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  tags                = local.config.tags
  sku                 = local.config.sku
  capacity            = local.config.capacity
}

resource "azurerm_servicebus_namespace_authorization_rule" "this" {
  for_each = { for k, v in local.config.authorization_rules : k => v if length(azurerm_servicebus_namespace.this) > 0 }

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.this[0].id
  listen       = each.value.manage || each.value.listen
  send         = each.value.manage || each.value.send
  manage       = each.value.manage
}

resource "azurerm_servicebus_queue" "this" {
  for_each = { for k, v in local.config.queues : k => v if length(azurerm_servicebus_namespace.this) > 0 }

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.this[0].id
}

resource "azurerm_servicebus_queue_authorization_rule" "this" {
  for_each = merge([ for k, v in local.config.queues : {
    for x, y in v.authorization_rules : x => merge(
      {
        queue_id = azurerm_servicebus_queue.this[k].id
      },
      y
    )
  } if length(azurerm_servicebus_namespace.this) > 0 ]...)

  name     = each.value.name
  queue_id = each.value.queue_id
  listen   = each.value.manage || each.value.listen
  send     = each.value.manage || each.value.send
  manage   = each.value.manage
}

resource "azurerm_servicebus_topic" "this" {
  for_each = { for k, v in local.config.topics : k => v if length(azurerm_servicebus_namespace.this) > 0 }

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.this[0].id
}

resource "azurerm_servicebus_topic_authorization_rule" "this" {
  for_each = merge([ for k, v in local.config.topics : {
    for x, y in v.authorization_rules : x => merge(
      {
        topic_id = azurerm_servicebus_topic.this[k].id
      },
      y
    )
  } if length(azurerm_servicebus_namespace.this) > 0 ]...)

  name     = each.value.name
  topic_id = each.value.topic_id
  listen   = each.value.manage || each.value.listen
  send     = each.value.manage || each.value.send
  manage   = each.value.manage
}
