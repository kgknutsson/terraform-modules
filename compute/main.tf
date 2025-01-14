locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name                = var.config.global.name
    location            = var.resource_group.location
    resource_group_name = var.resource_group.name

    naming = {
      for i in ["azurerm_linux_virtual_machine_scale_set"] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = compact([var.environment])
          random_length = null
          use_slug      = null
        },
        try(lookup(var.config.global.compute.naming, i), {}),
        try(lookup(local.env_config.compute.naming, i), {})
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
      try(var.config.global.compute.tags, {}),
      try(local.env_config.compute.tags, {})
    )

    type                   = try(local.env_config.compute.type, var.config.global.compute.type, null)
    os_type                = try(local.env_config.compute.os_type, var.config.global.compute.os_type, "Linux")
    sku                    = try(local.env_config.compute.sku, var.config.global.compute.sku, "Standard_DS1_v2")
    instances              = try(local.env_config.compute.instances, var.config.global.compute.instances, 1)
    computer_name_prefix   = try(local.env_config.compute.computer_name_prefix, var.config.global.compute.computer_name_prefix, null)
    secure_boot_enabled    = try(local.env_config.compute.secure_boot_enabled, var.config.global.compute.secure_boot_enabled, null)
    vtpm_enabled           = try(local.env_config.compute.vtpm_enabled, var.config.global.compute.vtpm_enabled, null)
    overprovision          = try(local.env_config.compute.overprovision, var.config.global.compute.overprovision, null)
    single_placement_group = try(local.env_config.compute.single_placement_group, var.config.global.compute.single_placement_group, null)
    source_image_id        = try(local.env_config.compute.source_image_id, var.config.global.compute.source_image_id, null)
    source_image_reference = try(local.env_config.compute.source_image_reference, var.config.global.compute.source_image_reference, null)
    custom_data            = try(local.env_config.compute.custom_data, var.config.global.compute.custom_data, null)
    admin_username         = try(local.env_config.compute.admin_username, var.config.global.compute.admin_username, "admin")
    admin_password         = try(local.env_config.compute.admin_password, var.config.global.compute.admin_password, null)

    admin_ssh_keys = merge(
      try(var.config.global.compute.admin_ssh_keys, {}),
      try(local.env_config.compute.admin_ssh_keys, {})
    )

    identity = {
      type         = try(local.env_config.compute.identity.type, var.config.global.compute.identity.type, "SystemAssigned")
      identity_ids = concat(try(var.config.global.compute.identity.identity_ids, []), try(local.env_config.compute.identity.identity_ids, []))
    }

    network_interfaces = {
      for i, v in compact(concat(
        keys(try(local.env_config.compute.network_interfaces, {})),
        keys(try(var.config.global.compute.network_interfaces, {}))
      )) : v => {
        primary                       = try(local.env_config.compute.network_interfaces[v].primary, var.config.global.compute.network_interfaces[v].primary, i == 0)
        enable_accelerated_networking = try(local.env_config.compute.network_interfaces[v].enable_accelerated_networking, var.config.global.compute.network_interfaces[v].enable_accelerated_networking, null)
        network_security_group_id     = try(local.env_config.compute.network_interfaces[v].network_security_group_id, var.config.global.compute.network_interfaces[v].network_security_group_id, null)
        ip_configurations             = try(local.env_config.compute.network_interfaces[v].ip_configurations, var.config.global.compute.network_interfaces[v].ip_configurations)
      } if try(local.env_config.compute.type, var.config.global.compute.type, null) != null
    }

    os_disk = {
      storage_account_type = try(local.env_config.compute.os_disk.storage_account_type, var.config.global.compute.os_disk.storage_account_type, "Standard_LRS") # Standard_LRS, StandardSSD_LRS, StandardSSD_ZRS, Premium_LRS or Premium_ZRS
      caching              = try(local.env_config.compute.os_disk.caching, var.config.global.compute.os_disk.caching, "None") # None, ReadOnly and ReadWrite
    }

    boot_diagnostics = {
      enabled             = try(local.env_config.compute.boot_diagnostics.enabled, var.config.global.compute.boot_diagnostics.enabled, false)
      storage_account_uri = try(local.env_config.compute.boot_diagnostics.storage_account_uri, var.config.global.compute.boot_diagnostics.storage_account_uri, var.storage_account.primary_blob_endpoint, null)
    }

    scale_in = {
      force_deletion_enabled = try(local.env_config.compute.scale_in.force_deletion_enabled, var.config.global.compute.scale_in.force_deletion_enabled, false)
      rule                   = try(local.env_config.compute.scale_in.rule, var.config.global.compute.scale_in.rule, "Default")
    }
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

resource "tls_private_key" "this" {
  count = min(
    length(local.config.type[*]),
    1 - length(local.config.admin_password[*]),
    1 - length(lookup(local.config.admin_ssh_keys, local.config.admin_username, null)[*])
  )

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurecaf_name" "linux_virtual_machine_scale_set" {
  count = length(local.config.type[*])

  name          = local.config.naming["azurerm_linux_virtual_machine_scale_set"].name
  resource_type = "azurerm_linux_virtual_machine_scale_set"
  prefixes      = local.config.naming["azurerm_linux_virtual_machine_scale_set"].prefixes
  suffixes      = local.config.naming["azurerm_linux_virtual_machine_scale_set"].suffixes
  random_length = local.config.naming["azurerm_linux_virtual_machine_scale_set"].random_length
  use_slug      = local.config.naming["azurerm_linux_virtual_machine_scale_set"].use_slug
}

resource "azurecaf_name" "network_interface" {
  for_each = local.config.network_interfaces

  name          = local.config.name
  resource_type = "azurerm_network_interface"
  suffixes      = [var.environment] #, each.key]
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  count = length(local.config.type[*])

  name                            = azurecaf_name.linux_virtual_machine_scale_set.0.result
  resource_group_name             = local.config.resource_group_name
  location                        = local.config.location
  sku                             = local.config.sku
  instances                       = local.config.instances
  computer_name_prefix            = local.config.computer_name_prefix
  secure_boot_enabled             = local.config.secure_boot_enabled
  vtpm_enabled                    = local.config.vtpm_enabled
  overprovision                   = local.config.overprovision
  single_placement_group          = local.config.single_placement_group
  source_image_id                 = local.config.source_image_id
  custom_data                     = try(base64encode(startswith(local.config.custom_data, "file:") ? file(format("%s/%s", path.root, split(":", local.config.custom_data)[1])) : local.config.custom_data), null)
  admin_username                  = local.config.admin_username
  admin_password                  = local.config.admin_password
  disable_password_authentication = local.config.admin_password == null
  tags                            = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  dynamic "network_interface" {
    for_each = local.config.network_interfaces

    content {
      name                          = azurecaf_name.network_interface[network_interface.key].result
      primary                       = network_interface.value.primary
      enable_accelerated_networking = network_interface.value.enable_accelerated_networking
      network_security_group_id     = network_interface.value.network_security_group_id

      dynamic "ip_configuration" {
        for_each = network_interface.value.ip_configurations

        content {
          name      = join("-", [azurecaf_name.network_interface[network_interface.key].result, ip_configuration.key])
          primary   = ip_configuration.value.primary
          subnet_id = try(var.virtual_network.subnet_id_map[ip_configuration.value.subnet_id], ip_configuration.value.subnet_id)
        }
      }
    }
  }

  dynamic "admin_ssh_key" {
    for_each = merge(
      { for i in tls_private_key.this : local.config.admin_username => i.public_key_openssh },
      local.config.admin_ssh_keys
    )

    content {
      username   = admin_ssh_key.key
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    storage_account_type = local.config.os_disk.storage_account_type
    caching              = local.config.os_disk.caching
  }
  dynamic "source_image_reference" {
    for_each = local.config.source_image_reference[*]

    content {
      publisher = source_image_reference.value.publisher
      offer     = source_image_reference.value.offer
      sku       = source_image_reference.value.sku
      version   = source_image_reference.value.version
    }
  }

  dynamic "boot_diagnostics" {
    for_each = local.config.boot_diagnostics.enabled ? [ local.config.boot_diagnostics.storage_account_uri ] : []

    content {
      storage_account_uri = boot_diagnostics.value
    }
  }

  scale_in {
    force_deletion_enabled = local.config.scale_in.force_deletion_enabled
    rule                   = local.config.scale_in.rule
  }

  lifecycle {
    ignore_changes = [ custom_data ]
  }
}
