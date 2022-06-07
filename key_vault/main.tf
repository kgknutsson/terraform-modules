locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name           = var.config.global.name
    location       = var.config.global.location

    tags = merge({
      application       = var.config.global.name
      environment       = var.environment
      terraform         = "true"
    }, var.tags)

    sku_name                        = try(local.env_config.key_vault.sku_name, var.config.global.key_vault.sku_name, "standard")
    enabled_for_template_deployment = try(local.env_config.key_vault.enabled_for_template_deployment, var.config.global.key_vault.enabled_for_template_deployment, true)

    network_acls = {
      bypass                     = try(local.env_config.key_vault.network_acls.bypass, var.config.global.key_vault.network_acls.bypass, "AzureServices")
      default_action             = try(local.env_config.key_vault.network_acls.default_action, var.config.global.key_vault.network_acls.default_action, "Deny")
      ip_rules                   = concat(try(var.config.global.key_vault.network_acls.ip_rules, []), try(local.env_config.key_vault.network_acls.ip_rules, []))
      virtual_network_subnet_ids = matchkeys(values(var.subnet_ids), keys(var.subnet_ids), concat(try(var.config.global.key_vault.network_acls.subnets, []), try(local.env_config.key_vault.network_acls.subnets, [])))
    }
  }
}

data "azurerm_client_config" "this" {}

resource "azurecaf_name" "key_vault" {
  name          = local.config.name
  resource_type = "azurerm_key_vault"
  suffixes      = [var.environment]
  random_length = 10
}

resource "azurerm_key_vault" "this" {
  name                            = azurecaf_name.key_vault.result
  resource_group_name             = var.resource_group
  location                        = local.config.location
  tags                            = local.config.tags
  tenant_id                       = data.azurerm_client_config.this.tenant_id
  sku_name                        = local.config.sku_name
  enabled_for_template_deployment = local.config.enabled_for_template_deployment

  network_acls {
    bypass = local.config.network_acls.bypass
    default_action = local.config.network_acls.default_action
    ip_rules = local.config.network_acls.ip_rules
    virtual_network_subnet_ids = local.config.network_acls.virtual_network_subnet_ids
  }
}
