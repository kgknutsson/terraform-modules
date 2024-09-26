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
      try(var.config.global.static_web_app.tags, {}),
      try(local.env_config.static_web_app.tags, {})
    )

    sites = {
      for i in coalescelist(
        keys(merge(
          try(local.env_config.static_web_app.sites, {}),
          try(var.config.global.static_web_app.sites, {})
        )),
        [var.config.global.name]
        ) : i => {
        sku_name = try(
          local.env_config.static_web_app.sites[i].sku_name,
          var.config.global.static_web_app.sites[i].sku_name,
          local.env_config.static_web_app.sku_name,
          var.config.global.static_web_app.sku_name,
          "Standard"
        ) //Free or Standard

        identity = {
          type = try(
            local.env_config.static_web_app.sites[i].identity.type,
            var.config.global.static_web_app.sites[i].identity.type,
            local.env_config.static_web_app.identity.type,
            var.config.global.static_web_app.identity.type,
            null
          )
          identity_ids = concat(
            try(var.config.global.static_web_app.sites[i].identity.identity_ids, []),
            try(local.env_config.static_web_app.sites[i].identity.identity_ids, []),
            try(var.config.global.static_web_app.identity.identity_ids, []),
            try(local.env_config.static_web_app.identity.identity_ids, [])
          )
        }

        app_settings = merge(
          try(var.config.global.static_web_app.app_settings, {}),
          try(local.env_config.static_web_app.app_settings, {}),
          try(var.config.global.static_web_app.sites[i].app_settings, {}),
          try(local.env_config.static_web_app.sites[i].app_settings, {})
        )

        custom_domains = coalesce(
          try(
            local.env_config.static_web_app.sites[i].custom_domains,
            var.config.global.static_web_app.sites[i].custom_domains,
            local.env_config.static_web_app.custom_domains,
            var.config.global.static_web_app.custom_domains,
            []
          ),
          []
        )

        tags = merge(
          {
            "application" : i
          },
          try(var.config.global.static_web_app.sites[i].tags, {}),
          try(local.env_config.static_web_app.sites[i].tags, {})
        )
      }
    }
  }
}

resource "azurecaf_name" "static_web_app" {
  for_each = local.config.sites

  name          = each.key
  resource_type = "azurerm_static_site" // The resource type azurerm_static_web_app is not yet supported
  suffixes      = [var.environment]
}

resource "azurerm_static_web_app" "this" {
  for_each = local.config.sites

  name                = azurecaf_name.static_web_app[each.key].result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  sku_size            = each.value.sku_name
  sku_tier            = each.value.sku_name
  app_settings        = each.value.app_settings
  tags                = merge(local.config.tags, each.value.tags)

  dynamic "identity" {
    for_each = each.value.identity.type[*]

    content {
      type         = each.value.identity.type
      identity_ids = each.value.identity.identity_ids
    }
  }
}

resource "azurerm_static_web_app_custom_domain" "this" {
  for_each = transpose({ for k, v in local.config.sites : k => v.custom_domains if length(v.custom_domains) > 0 })

  static_web_app_id = azurerm_static_web_app.this[each.value.0].id
  domain_name       = each.key
  validation_type   = "cname-delegation"

  timeouts {}

  lifecycle {
    ignore_changes = [
      validation_type,
    ]
  }
}
