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
      try(var.config.global.key_vault.tags, {}),
      try(local.env_config.key_vault.tags, {})
    )

    sku_name                        = try(local.env_config.key_vault.sku_name, var.config.global.key_vault.sku_name, null) // standard or premium
    enable_rbac_authorization       = try(local.env_config.key_vault.enable_for_rbac_authorization, var.config.global.key_vault.enable_for_rbac_authorization, null)
    enabled_for_deployment          = try(local.env_config.key_vault.enabled_for_deployment, var.config.global.key_vault.enabled_for_deployment, null)
    enabled_for_disk_encryption     = try(local.env_config.key_vault.enabled_for_disk_encryption, var.config.global.key_vault.enabled_for_disk_encryption, null)
    enabled_for_template_deployment = try(local.env_config.key_vault.enabled_for_template_deployment, var.config.global.key_vault.enabled_for_template_deployment, true)
    purge_protection_enabled        = try(local.env_config.key_vault.purge_protection_enabled, var.config.global.key_vault.purge_protection_enabled, false)
    soft_delete_retention_days      = try(local.env_config.key_vault.soft_delete_retention_days, var.config.global.key_vault.soft_delete_retention_days, 90)
    public_network_access_enabled   = try(local.env_config.key_vault.public_network_access_enabled, var.config.global.key_vault.public_network_access_enabled, false)

    network_acls = {
      bypass                     = try(local.env_config.key_vault.network_acls.bypass, var.config.global.key_vault.network_acls.bypass, "AzureServices")
      default_action             = try(local.env_config.key_vault.network_acls.default_action, var.config.global.key_vault.network_acls.default_action, "Deny")
      ip_rules                   = concat(try(var.config.global.key_vault.network_acls.ip_rules, []), try(local.env_config.key_vault.network_acls.ip_rules, []))
      virtual_network_subnet_ids = matchkeys(
        try(values(var.virtual_network.subnet_ids), []),
        try(keys(var.virtual_network.subnet_ids), []),
        concat(
          try(var.config.global.key_vault.network_acls.subnets, []),
          try(local.env_config.key_vault.network_acls.subnets, [])
        )
      )
    }
  }
}

data "azurerm_client_config" "this" {}

resource "azurecaf_name" "key_vault" {
  count = local.config.sku_name != null ? 1 : 0

  name          = local.config.name
  resource_type = "azurerm_key_vault"
  suffixes      = [var.environment]
  random_length = 10
}

resource "azurerm_key_vault" "this" {
  count = length(azurecaf_name.key_vault)

  name                            = azurecaf_name.key_vault.0.result
  resource_group_name             = local.config.resource_group_name
  location                        = local.config.location
  tags                            = local.config.tags
  tenant_id                       = data.azurerm_client_config.this.tenant_id
  sku_name                        = local.config.sku_name
  enable_rbac_authorization       = local.config.enable_rbac_authorization
  enabled_for_deployment          = local.config.enabled_for_deployment
  enabled_for_disk_encryption     = local.config.enabled_for_disk_encryption
  enabled_for_template_deployment = local.config.enabled_for_template_deployment
  #tfsec:ignore:azure-keyvault-no-purge
  purge_protection_enabled        = local.config.purge_protection_enabled
  soft_delete_retention_days      = local.config.soft_delete_retention_days
  public_network_access_enabled   = local.config.public_network_access_enabled

  network_acls {
    bypass = local.config.network_acls.bypass
    default_action = local.config.network_acls.default_action
    ip_rules = local.config.network_acls.ip_rules
    virtual_network_subnet_ids = local.config.network_acls.virtual_network_subnet_ids
  }
}
