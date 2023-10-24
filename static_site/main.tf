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
      try(var.config.global.static_site.tags, {}),
      try(local.env_config.static_site.tags, {})
    )

    sites = {
      for i in coalescelist(
        keys(merge(
          try(local.env_config.static_site.sites, {}),
          try(var.config.global.static_site.sites, {})
        )),
        [var.config.global.name]
        ) : i => {
        sku_name = try(
          local.env_config.static_site.sites[i].sku_name,
          var.config.global.static_site.sites[i].sku_name,
          local.env_config.static_site.sku_name,
          var.config.global.static_site.sku_name,
          "Standard"
        ) //Free or Standard

        identity = {
          type = try(
            local.env_config.static_site.sites[i].identity.type,
            var.config.global.static_site.sites[i].identity.type,
            local.env_config.static_site.identity.type,
            var.config.global.static_site.identity.type,
            null
          )
          identity_ids = concat(
            try(var.config.global.static_site.sites[i].identity.identity_ids, []),
            try(local.env_config.static_site.sites[i].identity.identity_ids, []),
            try(var.config.global.static_site.identity.identity_ids, []),
            try(local.env_config.static_site.identity.identity_ids, [])
          )
        }

        app_settings = merge(
          try(var.config.global.static_site.app_settings, {}),
          try(local.env_config.static_site.app_settings, {}),
          try(var.config.global.static_site.sites[i].app_settings, {}),
          try(local.env_config.static_site.sites[i].app_settings, {})
        )

        custom_domains = coalesce(
          try(
            local.env_config.static_site.sites[i].custom_domains,
            var.config.global.static_site.sites[i].custom_domains,
            local.env_config.static_site.custom_domains,
            var.config.global.static_site.custom_domains,
            []
          ),
          []
        )

        tags = merge(
          {
            "application" : i
          },
          try(var.config.global.static_site.sites[i].tags, {}),
          try(local.env_config.static_site.sites[i].tags, {})
        )
      }
    }
  }
}

resource "azurecaf_name" "static_site" {
  for_each = local.config.sites

  name          = each.key
  resource_type = "azurerm_static_site"
  suffixes      = [var.environment]
}

resource "azurerm_static_site" "this" {
  for_each = local.config.sites

  name                = azurecaf_name.static_site[each.key].result
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

resource "azurerm_static_site_custom_domain" "this" {
  for_each = transpose({ for k, v in local.config.sites : k => v.custom_domains if length(v.custom_domains) > 0 })

  static_site_id  = azurerm_static_site.this[each.value.0].id
  domain_name     = each.key
  validation_type = "cname-delegation"

  timeouts {}

  lifecycle {
    ignore_changes = [
      validation_type,
    ]
  }
}
