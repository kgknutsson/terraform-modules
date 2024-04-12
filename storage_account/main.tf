locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    location            = var.resource_group.location
    resource_group_name = var.resource_group.name

    naming = {
      for i in ["azurerm_storage_account"] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = null
          random_length = 10
          use_slug      = null
        },
        try(lookup(var.config.global.storage_account.naming, i), {}),
        try(lookup(local.env_config.storage_account.naming, i), {})
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
      try(var.config.global.storage_account.tags, {}),
      try(local.env_config.storage_account.tags, {})
    )

    account_kind                  = try(local.env_config.storage_account.account_kind, var.config.global.storage_account.account_kind, "StorageV2") // BlobStorage, BlockBlobStorage, FileStorage, Storage or StorageV2
    account_tier                  = try(local.env_config.storage_account.account_tier, var.config.global.storage_account.account_tier, null) // Standard or Premium
    account_replication_type      = try(local.env_config.storage_account.account_replication_type, var.config.global.storage_account.account_replication_type, "LRS") // LRS, GRS, RAGRS, ZRS, GZRS or RAGZRS
    access_tier                   = try(local.env_config.storage_account.access_tier, var.config.global.storage_account.access_tier, "Hot") // Hot or Cold
    min_tls_version               = try(local.env_config.storage_account.min_tls_version, var.config.global.storage_account.min_tls_version, "TLS1_2") // TLS1_0, TLS1_1, or TLS1_2
    shared_access_key_enabled     = try(local.env_config.storage_account.shared_access_key_enabled, var.config.global.storage_account.shared_access_key_enabled, true)
    public_network_access_enabled = try(local.env_config.storage_account.public_network_access_enabled, var.config.global.storage_account.public_network_access_enabled, true)
    is_hns_enabled                = try(local.env_config.storage_account.is_hns_enabled, var.config.global.storage_account.is_hns_enabled, false)
    sftp_enabled                  = try(local.env_config.storage_account.sftp_enabled, var.config.global.storage_account.sftp_enabled, false)

    network_rules = try(local.env_config.storage_account.network_rules, var.config.global.storage_account.network_rules, null) == null ? null : {
      bypass                     = coalescelist(tolist(setunion(try(local.env_config.storage_account.network_rules.bypass, []), try(var.config.global.storage_account.network_rules.bypass, []))), ["None"])  // Combination of Logging, Metrics, AzureServices, or None
      ip_rules                   = setunion(try(local.env_config.storage_account.network_rules.ip_rules, []), try(var.config.global.storage_account.network_rules.ip_rules, []))
      virtual_network_subnet_ids = [ for i in setunion(try(local.env_config.storage_account.network_rules.virtual_network_subnet_ids, []), try(var.config.global.storage_account.network_rules.virtual_network_subnet_ids, [])) : try(var.virtual_network.subnet_id_map[i], i)]
    }

    storage_containers = { for k in setunion(keys(try(local.env_config.storage_account.storage_containers, {})), keys(try(var.config.global.storage_account.storage_containers, {}))) : k => merge(
      {
        container_access_type = null
        metadata              = null
      },
      try(var.config.global.storage_account.storage_containers[k], {}),
      try(local.env_config.storage_account.storage_containers[k], {})
    ) }

    local_users = { for k in setunion(keys(try(local.env_config.storage_account.local_users, {})), keys(try(var.config.global.storage_account.local_users, {}))) : k => merge(
      {
        ssh_key_enabled      = null
        ssh_password_enabled = null
        home_directory       = null
        ssh_authorized_keys  = []
        permission_scopes    = {}
      },
      try(var.config.global.storage_account.local_users[k], {}),
      try(local.env_config.storage_account.local_users[k], {})
    ) }
  }
}

resource "azurecaf_name" "storage_account" {
  count = local.config.account_tier != null ? 1 : 0

  name           = local.config.naming["azurerm_storage_account"].name
  resource_type  = "azurerm_storage_account"
  prefixes       = local.config.naming["azurerm_storage_account"].prefixes
  suffixes       = local.config.naming["azurerm_storage_account"].suffixes
  random_length  = local.config.naming["azurerm_storage_account"].random_length
  use_slug       = local.config.naming["azurerm_storage_account"].use_slug
}

resource "azurerm_storage_account" "this" {
  count = length(azurecaf_name.storage_account)

  name                          = azurecaf_name.storage_account.0.result
  resource_group_name           = local.config.resource_group_name
  location                      = local.config.location
  account_kind                  = local.config.account_kind
  account_tier                  = local.config.account_tier
  account_replication_type      = local.config.account_replication_type
  access_tier                   = local.config.access_tier
  min_tls_version               = local.config.min_tls_version
  shared_access_key_enabled     = local.config.shared_access_key_enabled
  public_network_access_enabled = local.config.public_network_access_enabled
  is_hns_enabled                = local.config.is_hns_enabled
  sftp_enabled                  = local.config.sftp_enabled
  tags                          = local.config.tags

  dynamic "network_rules" {
    for_each = local.config.network_rules[*]

    content {
      default_action = "Deny"
      bypass = network_rules.value.bypass
      ip_rules = network_rules.value.ip_rules
      virtual_network_subnet_ids = network_rules.value.virtual_network_subnet_ids
    }
  }
}

resource "azurerm_storage_container" "this" {
  for_each = { for k, v in local.config.storage_containers : k => v if length(azurerm_storage_account.this) > 0 }

  name                  = each.key
  storage_account_name  = azurerm_storage_account.this.0.name
  container_access_type = each.value.container_access_type
  metadata              = each.value.metadata
}

resource "azurerm_storage_account_local_user" "this" {
  for_each = { for k, v in local.config.local_users : k => v if length(azurerm_storage_account.this) > 0 }

  name                 = each.key
  storage_account_id   = azurerm_storage_account.this.0.id
  ssh_key_enabled      = each.value.ssh_key_enabled
  ssh_password_enabled = each.value.ssh_password_enabled
  home_directory       = each.value.home_directory

  dynamic "ssh_authorized_key" {
    for_each = each.value.ssh_authorized_keys

    content {
      key         = try(ssh_authorized_key.value.key, ssh_authorized_key.value)
      description = try(ssh_authorized_key.value.description, null)
    }
  }

  dynamic "permission_scope" {
    for_each = each.value.permission_scopes

    content {
      resource_name = permission_scope.key
      service       = "blob"

      permissions {
        create = contains(permission_scope.value.permissions, "create")
        delete = contains(permission_scope.value.permissions, "delete")
        list   = contains(permission_scope.value.permissions, "list")
        read   = contains(permission_scope.value.permissions, "read")
        write  = contains(permission_scope.value.permissions, "write")
      }
    }
  }
}
