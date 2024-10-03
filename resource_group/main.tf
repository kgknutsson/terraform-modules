locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    location = try(local.env_config.location, var.config.global.location)

    naming = {
      for i in ["azurerm_resource_group"] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = compact([var.environment])
          random_length = null
          use_slug      = null
        },
        try(lookup(var.config.global.resource_group.naming, i), {}),
        try(lookup(local.env_config.resource_group.naming, i), {})
      )
    }

    tags = merge(
      {
        application = var.config.global.name
        environment = var.environment
        terraform   = "true"
      },
      var.tags,
      try(var.config.global.tags, {}),
      try(local.env_config.tags, {}),
      try(var.config.global.resource_group.tags, {}),
      try(local.env_config.resource_group.tags, {})
    )
  }
}

resource "azurecaf_name" "resource_group" {
  name           = local.config.naming["azurerm_resource_group"].name
  resource_type  = "azurerm_resource_group"
  prefixes       = local.config.naming["azurerm_resource_group"].prefixes
  suffixes       = local.config.naming["azurerm_resource_group"].suffixes
  random_length  = local.config.naming["azurerm_resource_group"].random_length
  use_slug       = local.config.naming["azurerm_resource_group"].use_slug
}

resource "azurerm_resource_group" "this" {
  name     = azurecaf_name.resource_group.result
  location = local.config.location
  tags     = local.config.tags
}
