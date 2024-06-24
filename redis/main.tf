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
      try(var.config.global.redis.tags, {}),
      try(local.env_config.redis.tags, {})
    )

    naming = {
      for i in [
        "azurerm_redis_cache",
      ] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = compact([var.environment])
          random_length = null
          use_slug      = null
        },
        try(lookup(var.config.global.redis.naming, i), {}),
        try(lookup(local.env_config.redis.naming, i), {})
      )
    }

    sku_name                      = try(local.env_config.redis.sku_name, var.config.global.redis.sku_name, null) // Basic, Standard or Premium
    capacity                      = try(local.env_config.redis.capacity, var.config.global.redis.capacity, 1)
    public_network_access_enabled = try(local.env_config.redis.public_network_access_enabled, var.config.global.redis.public_network_access_enabled, false)
    enable_non_ssl_port           = try(local.env_config.redis.enable_non_ssl_port, var.config.global.redis.enable_non_ssl_port, false)
    minimum_tls_version           = try(local.env_config.redis.minimum_tls_version, var.config.global.redis.minimum_tls_version, "1.2")
    redis_configuration           = try(local.env_config.redis.redis_configuration, var.config.global.redis.redis_configuration, null)

    identity = {
      type         = try(local.env_config.redis.identity.type, var.config.global.redis.identity.type, "SystemAssigned")
      identity_ids = concat(try(var.config.global.redis.identity.identity_ids, []), try(local.env_config.redis.identity.identity_ids, []))
    }
    access_policies = merge(
      try(var.config.global.redis.access_policies, {}),
      try(local.env_config.redis.access_policies, {})
    )

    access_policy_assignments = merge(
      try(var.config.global.redis.access_policy_assignments, {}),
      try(local.env_config.redis.access_policy_assignments, {})
    )
  }
}

resource "azurecaf_name" "user_assigned_identity" {
  count = try(endswith(local.config.identity.type, "UserAssigned"), false) && length(local.config.identity.identity_ids) == 0 ? 1 : 0

  name          = local.config.name
  resource_type = "azurerm_user_assigned_identity"
  suffixes      = [var.environment]
}

resource "azurerm_user_assigned_identity" "this" {
  count = length(azurecaf_name.user_assigned_identity)

  name                = azurecaf_name.user_assigned_identity.0.result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  tags                = local.config.tags
}

resource "azurecaf_name" "redis_cache" {
  count = length(local.config.sku_name[*])

  name           = local.config.naming["azurerm_redis_cache"].name
  resource_type = "azurerm_redis_cache"
  prefixes       = local.config.naming["azurerm_redis_cache"].prefixes
  suffixes       = local.config.naming["azurerm_redis_cache"].suffixes
  random_length  = local.config.naming["azurerm_redis_cache"].random_length
  use_slug       = local.config.naming["azurerm_redis_cache"].use_slug
}

resource "azurerm_redis_cache" "this" {
  count = length(azurecaf_name.redis_cache)

  name                          = azurecaf_name.redis_cache[0].result
  resource_group_name           = local.config.resource_group_name
  location                      = local.config.location
  tags                          = local.config.tags
  sku_name                      = local.config.sku_name
  family                        = local.config.sku_name == "Premium" ? "P" : "C"
  capacity                      = local.config.capacity
  public_network_access_enabled = local.config.public_network_access_enabled
  enable_non_ssl_port           = local.config.enable_non_ssl_port
  minimum_tls_version           = local.config.minimum_tls_version

  dynamic "redis_configuration" {
    for_each = [
      for i in local.config.redis_configuration[*] : merge(
        {
          azure_active_directory_enabled = null
        },
        i
      )
    ]

    content {
      active_directory_authentication_enabled = redis_configuration.value.active_directory_authentication_enabled
    }
  }

  dynamic "identity" {
    for_each = [
      for i in local.config.identity.type[*] : {
        type         = i
        identity_ids = i == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
      }
    ]

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }
}

resource "azurerm_redis_cache_access_policy" "this" {
  for_each = { for k, v in local.config.access_policies : k => v if length(azurerm_redis_cache.this) > 0 }

  name           = each.key
  redis_cache_id = azurerm_redis_cache.this[0].id
  permissions    = each.value
}

resource "azurerm_redis_cache_access_policy_assignment" "this" {
  for_each = { for k, v in local.config.access_policy_assignments : k => v if length(azurerm_redis_cache.this) > 0 }

  name               = each.key
  redis_cache_id     = azurerm_redis_cache.this[0].id
  access_policy_name = each.value.access_policy_name
  object_id          = each.value.object_id
  object_id_alias    = try(each.value.object_id_alias, each.key)
}
