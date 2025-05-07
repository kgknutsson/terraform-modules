locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    location            = var.resource_group.location
    resource_group_name = var.resource_group.name

    naming = {
      for i in ["azurerm_mssql_server", "azurerm_mssql_elasticpool", "azurerm_mssql_database"] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = compact([var.environment])
          random_length = null
          use_slug      = null
        },
        try(lookup(var.config.global.mssql_database.naming, i), {}),
        try(lookup(local.env_config.mssql_database.naming, i), {})
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
      try(var.config.global.mssql_database.tags, {}),
      try(local.env_config.mssql_database.tags, {})
    )

    version                                  = try(local.env_config.mssql_database.version, var.config.global.mssql_database.version, "12.0")
    minimum_tls_version                      = try(local.env_config.mssql_database.minimum_tls_version, var.config.global.mssql_database.minimum_tls_version, "Disabled")
    public_network_access_enabled            = try(local.env_config.mssql_database.public_network_access_enabled, var.config.global.mssql_database.public_network_access_enabled, false)
    administrator_login                      = try(local.env_config.mssql_database.administrator_login, var.config.global.mssql_database.administrator_login, null)
    administrator_login_password             = try(local.env_config.mssql_database.administrator_login_password, var.config.global.mssql_database.administrator_login_password, null)
    express_vulnerability_assessment_enabled = try(local.env_config.mssql_database.express_vulnerability_assessment_enabled, var.config.global.mssql_database.express_vulnerability_assessment_enabled, true)

    azuread_administrator = merge(
      {
        login_username              = null
        object_id                   = null
        azuread_authentication_only = true
      },
      try(var.config.global.mssql_database.azuread_administrator, {}),
      try(local.env_config.mssql_database.azuread_administrator, {})
    )

    identity = {
      type         = try(local.env_config.mssql_database.identity.type, var.config.global.mssql_database.identity.type, null)
      identity_ids = concat(try(var.config.global.mssql_database.identity.identity_ids, []), try(local.env_config.mssql_database.identity.identity_ids, []))
    }

    elastic_pools = { for k in setunion(keys(try(local.env_config.mssql_database.elastic_pools, {})), keys(try(var.config.global.mssql_database.elastic_pools, {}))) : k => merge(
      {
        suffixes                       = []
        enclave_type                   = "Default"
        maintenance_configuration_name = null
        max_size_gb                    = 10
        license_type                   = "LicenseIncluded"
        tags                           = {}
        sku = {
          name     = "GP_Gen5"
          tier     = "GeneralPurpose"
          family   = "Gen5"
          capacity = 2
        }
        per_database_settings = {
          min_capacity = 0
          max_capacity = 2
        }
      },
      try(var.config.global.mssqldatabase.elastic_pools[k], {}),
      try(local.env_config.mssql_database.elastic_pools[k], {})
    ) }

    databases = { for k in setunion(keys(try(local.env_config.mssql_database.databases, {})), keys(try(var.config.global.mssql_database.databases, {}))) : k => merge(
      {
        create_mode                    = "Default"
        creation_source_database_id    = null
        collation                      = try(local.env_config.mssql_database.default_collation, var.config.global.mssql_database.default_collation, "Finnish_Swedish_CI_AS")
        enclave_type                   = try(local.env_config.mssql_database.default_enclave_type, var.config.global.mssql_database.default_enclave_type, "Default")
        maintenance_configuration_name = try(local.env_config.mssql_database.default_maintenance_configuration_name, var.config.global.mssql_database.default_maintenance_configuration_name, null)
        short_term_retention_policy    = try(local.env_config.mssql_database.default_short_term_retention_policy, var.config.global.mssql_database.default_short_term_retention_policy, null)
        long_term_retention_policy     = try(local.env_config.mssql_database.default_long_term_retention_policy, var.config.global.mssql_database.default_long_term_retention_policy, null)
        license_type                   = try(local.env_config.mssql_database.default_license_type, var.config.global.mssql_database.default_license_type, null)
        max_size_gb                    = try(local.env_config.mssql_database.default_max_gb_size, var.config.global.mssql_database.default_max_gb_size, 2)
        read_scale                     = try(local.env_config.mssql_database.default_read_scale, var.config.global.mssql_database.default_read_scale, false)
        sku_name                       = try(local.env_config.mssql_database.default_sku_name, var.config.global.mssql_database.default_sku_name, "S0")
        elastic_pool                   = try(local.env_config.mssql_database.default_elastic_pool, var.config.global.mssql_database.default_elastic_pool, null)
        zone_redundant                 = try(local.env_config.mssql_database.default_zone_redundant, var.config.global.mssql_database.default_zone_redundant, false)
        user_assigned_identity         = true
        tags                           = { application = k }
      },
      try(var.config.global.mssql_database.databases[k], {}),
      try(local.env_config.mssql_database.databases[k], {}),
      {
        instances = { for i in setunion(
          keys(try(var.config.global.mssql_database.databases[k].instances, {})),
          keys(try(local.env_config.mssql_database.databases[k].instances, {}))
        ) : i == "_" ? k : format("%s-%s", k, i) => merge(
          try(var.config.global.mssql_database.databases[k].instances[i], {}),
          try(local.env_config.mssql_database.databases[k].instances[i], {})
        ) }
      }
    ) }

    monitor_activity_log_alerts = { for k in setunion(keys(try(local.env_config.mssql_database.monitor.activity_log_alerts, {})), keys(try(var.config.global.mssql_database.monitor.activity_log_alerts, {}))) : k => concat(
      try(local.env_config.mssql_database.monitor.activity_log_alerts[k], []),
      try(var.config.global.mssqldatabase.monitor.activity_log_alerts[k], [])
    ) }

    monitor_metric_alerts = { for k in setunion(keys(try(local.env_config.mssql_database.monitor.metric_alerts, {})), keys(try(var.config.global.mssql_database.monitor.metric_alerts, {}))) : k => concat(
      try(local.env_config.mssql_database.monitor.metric_alerts[k], []),
      try(var.config.global.mssqldatabase.monitor.metric_alerts[k], [])
    ) }

    monitor_activity_log_alerts_enabled = try(local.env_config.mssql_database.monitor.activity_log_alerts_enabled, var.config.global.mssql_database.monitor.activity_log_alerts_enabled, true)
    monitor_metric_alerts_enabled       = try(local.env_config.mssql_database.monitor.metric_alerts_enabled, var.config.global.mssql_database.monitor.metric_alerts_enabled, true)
    monitor_default_action_group_ids    = concat(try(local.env_config.mssql_database.monitor.default_action_group_ids, []), try(var.config.global.mssql_database.monitor.default_action_group_ids, []))
  }
}

resource "azurecaf_name" "mssql_server" {
  name           = local.config.naming["azurerm_mssql_server"].name
  resource_type  = "azurerm_mssql_server"
  prefixes       = local.config.naming["azurerm_mssql_server"].prefixes
  suffixes       = local.config.naming["azurerm_mssql_server"].suffixes
  random_length  = local.config.naming["azurerm_mssql_server"].random_length
  use_slug       = local.config.naming["azurerm_mssql_server"].use_slug
}

resource "azurerm_mssql_server" "this" {
  name                                     = azurecaf_name.mssql_server.result
  resource_group_name                      = local.config.resource_group_name
  location                                 = local.config.location
  tags                                     = local.config.tags
  version                                  = local.config.version
  minimum_tls_version                      = local.config.minimum_tls_version
  public_network_access_enabled            = local.config.public_network_access_enabled
  administrator_login                      = local.config.administrator_login
  administrator_login_password             = local.config.administrator_login_password
  express_vulnerability_assessment_enabled = local.config.express_vulnerability_assessment_enabled

  azuread_administrator {
    login_username              = local.config.azuread_administrator.login_username
    object_id                   = local.config.azuread_administrator.object_id
    azuread_authentication_only = local.config.azuread_administrator.azuread_authentication_only
  }

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = identity.value
      identity_ids = local.config.identity.identity_ids
    }
  }
}

resource "azurecaf_name" "mssql_elasticpool" {
  for_each = local.config.elastic_pools

  name           = local.config.naming["azurerm_mssql_elasticpool"].name
  resource_type = "azurerm_mssql_elasticpool"
  prefixes       = local.config.naming["azurerm_mssql_elasticpool"].prefixes
  suffixes       = concat(local.config.naming["azurerm_mssql_elasticpool"].suffixes, [each.key])
  random_length  = local.config.naming["azurerm_mssql_elasticpool"].random_length
  use_slug       = local.config.naming["azurerm_mssql_elasticpool"].use_slug
}

resource "azurerm_mssql_elasticpool" "this" {
  for_each = local.config.elastic_pools

  name                           = azurecaf_name.mssql_elasticpool[each.key].result
  resource_group_name            = local.config.resource_group_name
  location                       = local.config.location
  server_name                    = azurerm_mssql_server.this.name
  enclave_type                   = each.value.enclave_type
  maintenance_configuration_name = each.value.maintenance_configuration_name
  max_size_gb                    = each.value.max_size_gb
  license_type                   = each.value.license_type
  tags                           = merge(local.config.tags, each.value.tags)

  sku {
    name     = each.value.sku.name
    tier     = each.value.sku.tier
    family   = each.value.sku.family
    capacity = each.value.sku.capacity
  }

  per_database_settings {
   min_capacity = each.value.per_database_settings.min_capacity
   max_capacity = each.value.per_database_settings.max_capacity
  }
}

resource "azurecaf_name" "mssql_database" {
  for_each = transpose({ for k, v in local.config.databases : k => coalescelist(keys(v.instances), [k]) })

  name          = each.key
  resource_type = "azurerm_mssql_database"
  prefixes      = local.config.naming["azurerm_mssql_database"].prefixes
  suffixes      = local.config.naming["azurerm_mssql_database"].suffixes
  random_length = local.config.naming["azurerm_mssql_database"].random_length
  use_slug      = local.config.naming["azurerm_mssql_database"].use_slug
}

resource "azurerm_mssql_database" "this" {
  for_each = transpose({ for k, v in local.config.databases : k => coalescelist(keys(v.instances), [k]) })

  name                           = azurecaf_name.mssql_database[each.key].result
  server_id                      = azurerm_mssql_server.this.id
  create_mode                    = try(local.config.databases[each.value.0].instances[each.key].create_mode, local.config.databases[each.value.0].create_mode)
  creation_source_database_id    = try(local.config.databases[each.value.0].instances[each.key].creation_source_database_id, local.config.databases[each.value.0].creation_source_database_id)
  collation                      = try(local.config.databases[each.value.0].instances[each.key].collation, local.config.databases[each.value.0].collation)
  enclave_type                   = try(local.config.databases[each.value.0].instances[each.key].enclave_type, local.config.databases[each.value.0].enclave_type)
  maintenance_configuration_name = contains(["Basic", "S0", "S1"], try(local.config.databases[each.value.0].instances[each.key].sku_name, local.config.databases[each.value.0].sku_name)) || try(azurerm_mssql_elasticpool.this[local.config.databases[each.value.0].elastic_pool].id, local.config.databases[each.value.0].elastic_pool) != null ? null : try(local.config.databases[each.value.0].instances[each.key].maintenance_configuration_name, local.config.databases[each.value.0].maintenance_configuration_name)
  license_type                   = try(local.config.databases[each.value.0].instances[each.key].license_type, local.config.databases[each.value.0].license_type)
  max_size_gb                    = try(local.config.databases[each.value.0].instances[each.key].max_size_gb, local.config.databases[each.value.0].max_size_gb)
  read_scale                     = try(local.config.databases[each.value.0].instances[each.key].read_scale, local.config.databases[each.value.0].read_scale)
  sku_name                       = try(local.config.databases[each.value.0].instances[each.key].sku_name, local.config.databases[each.value.0].sku_name)
  elastic_pool_id                = try(azurerm_mssql_elasticpool.this[local.config.databases[each.value.0].elastic_pool].id, local.config.databases[each.value.0].elastic_pool)
  zone_redundant                 = try(local.config.databases[each.value.0].instances[each.key].zone_redundant, local.config.databases[each.value.0].zone_redundant)
  tags                           = merge(local.config.tags, local.config.databases[each.value.0].tags)

  dynamic "short_term_retention_policy" {
    for_each = try(local.config.databases[each.value.0].instances[each.key].short_term_retention_policy, local.config.databases[each.value.0].short_term_retention_policy)[*]

    content {
      retention_days           = short_term_retention_policy.value.retention_days
      backup_interval_in_hours = try(short_term_retention_policy.value.backup_interval_in_hours, null)
    }
  }

  dynamic "long_term_retention_policy" {
    for_each = [
      for i in try(local.config.databases[each.value.0].instances[each.key].long_term_retention_policy, local.config.databases[each.value.0].long_term_retention_policy)[*] : merge(
        {
          weekly_retention         = null // Between 1 and 520 weeks in ISO8601 format e.g. P1Y, P1M, P1W or P7D
          monthly_retention        = null // Between 1 and 120 months in ISO8601 format e.g. P1Y, P1M, P4W or P30D
          yearly_retention         = null // Between 1 and 10 years in ISO8601 format e.g. P1Y, P12M, P52W or P365D
          week_of_year             = null // Between 1 and 52
        },
        i
      )
    ]

    content {
      weekly_retention         = long_term_retention_policy.value.weekly_retention
      monthly_retention        = long_term_retention_policy.value.monthly_retention
      yearly_retention         = long_term_retention_policy.value.yearly_retention
      week_of_year             = long_term_retention_policy.value.week_of_year
    }
  }
}

resource "azurecaf_name" "user_assigned_identity" {
  for_each = { for k, v in local.config.databases : k => v if v.user_assigned_identity }

  name          = each.key
  resource_type = "azurerm_user_assigned_identity"
  suffixes      = [var.environment]
}

resource "azurerm_user_assigned_identity" "this" {
  for_each = { for k, v in local.config.databases : k => v if v.user_assigned_identity }

  name                = azurecaf_name.user_assigned_identity[each.key].result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  tags                = merge(local.config.tags, each.value.tags)
}
