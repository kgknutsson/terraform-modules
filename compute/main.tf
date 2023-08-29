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
      try(var.config.global.compute.tags, {}),
      try(local.env_config.compute.tags, {})
    )

    type           = try(local.env_config.compute.type, var.config.global.compute.type, null)
    os_type        = try(local.env_config.compute.os_type, var.config.global.compute.os_type, "Linux")
    size           = try(local.env_config.compute.size, var.config.global.compute.size, "Standard_DS1_v2")
    instances      = try(local.env_config.compute.instances, var.config.global.compute.instances, 1)
    admin_username = try(local.env_config.compute.admin_username, var.config.global.compute.admin_username, "admin")
    admin_password = try(local.env_config.compute.admin_password, var.config.global.compute.admin_password, null)

    admin_ssh_key = merge(
      try(var.config.global.compute.admin_ssh_keys, {}),
      try(local.env_config.compute.admin_ssh_keys, {})
    )

    identity = {
      type         = try(local.env_config.compute.identity.type, var.config.global.compute.identity.type, "SystemAssigned")
      identity_ids = concat(try(var.config.global.compute.identity.identity_ids, []), try(local.env_config.compute.identity.identity_ids, []))
    }

    subnet_id = try(
      var.virtual_network.subnet_ids[local.env_config.compute.subnet_id],
      local.env_config.compute.subnet_id,
      var.virtual_network.subnet_ids[var.config.global.compute.subnet_id],
      var.config.global.compute.subnet_id,
      null
    )

    source_image_reference = merge(
      {
        publisher = "canonical"
        offer = "0001-com-ubuntu-server-focal"
        sku = "20_04-lts-gen2"
        version = "latest"
      },
      try(var.config.global.compute.source_image_reference, {}),
      try(local.env_config.compute.source_image_reference, {})
    )

    os_disk = {
      storage_account_type = try(local.env_config.compute.os_disk.storage_account_type, var.config.global.compute.os_disk.storage_account_type, "Standard_LRS") # Standard_LRS, StandardSSD_LRS, StandardSSD_ZRS, Premium_LRS or Premium_ZRS
      caching              = try(local.env_config.compute.os_disk.caching, var.config.global.compute.os_disk.caching, "None") # None, ReadOnly and ReadWrite
    }

    custom_data = try(local.env_config.compute.custom_data, var.config.global.compute.custom_data, null)
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
  count = length(local.config.type[*])

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurecaf_name" "linux_virtual_machine_scale_set" {
  count = length(local.config.type[*])

  name          = local.config.name
  resource_type = "azurerm_linux_virtual_machine_scale_set"
  suffixes      = [var.environment]
  #random_length = 5
}

resource "azurecaf_name" "network_interface" {
  count = length(local.config.type[*])

  name          = local.config.name
  resource_type = "azurerm_network_interface"
  suffixes      = [var.environment]
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  count = length(local.config.type[*])

  name                            = azurecaf_name.linux_virtual_machine_scale_set.0.result
  resource_group_name             = local.config.resource_group_name
  location                        = local.config.location
  sku                             = local.config.size
  instances                       = local.config.instances
  admin_username                  = local.config.admin_username
  admin_password                  = local.config.admin_password
  disable_password_authentication = local.config.admin_password == null
  custom_data                     = base64encode(local.config.custom_data)
  tags                            = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  network_interface {
    name    = azurecaf_name.network_interface.0.result
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = local.config.subnet_id
    }
  }
  dynamic "admin_ssh_key" {
    for_each = local.config.admin_ssh_key

    content {
      username   = admin_ssh_key.key
      public_key = coalesce(admin_ssh_key.value, tls_private_key.this.0.public_key_openssh)
    }
  }

  os_disk {
    storage_account_type = local.config.os_disk.storage_account_type
    caching              = local.config.os_disk.caching
  }

  source_image_reference {
    publisher = local.config.source_image_reference.publisher
    offer     = local.config.source_image_reference.offer
    sku       = local.config.source_image_reference.sku
    version   = local.config.source_image_reference.version
  }

  dynamic "boot_diagnostics" {
    for_each = var.storage_account[*].primary_blob_endpoint

    content {
      storage_account_uri = boot_diagnostics.value
    }
  }

  lifecycle {
    ignore_changes = [ custom_data ]
  }
}
