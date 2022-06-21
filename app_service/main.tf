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

    type                   = try(local.env_config.app_service.type, var.config.global.app_service.type, "WebApp") // WebApp or FunctionApp
    os_type                = try(local.env_config.app_service.os_type, var.config.global.app_service.os_type, "Windows") // Windows or Linux
    sku_name               = try(local.env_config.app_service.sku_name, var.config.global.app_service.sku_name, "S1")
    worker_count           = try(local.env_config.app_service.worker_count, var.config.global.app_service.worker_count, 1)
    https_only             = try(local.env_config.app_service.https_only, var.config.global.app_service.https_only, true)
    zone_balancing_enabled = try(local.env_config.app_service.zone_balancing_enabled, var.config.global.app_service.zone_balancing_enabled, false)
    metric_alerts          = try(local.env_config.app_service.metric_alerts, var.config.global.app_service.metric_alerts, true)

    diagnostic_categories = {
      logs    = try(local.env_config.app_service.diagnostic_categories.logs, var.config.global.app_service.diagnostic_categories.logs, null)
      metrics = try(local.env_config.app_service.diagnostic_categories.metrics, var.config.global.app_service.diagnostic_categories.metrics, null)
    }

    insights = {
      application_type     = try(local.env_config.app_service.insights.application_type, var.config.global.app_service.insights.application_type, "java")
      disable_ip_masking   = try(local.env_config.app_service.insights.disable_ip_masking, var.config.global.app_service.insights.disable_ip_masking, false)
      daily_data_cap_in_gb = try(local.env_config.app_service.insights.daily_data_cap_in_gb, var.config.global.app_service.insights.daily_data_cap_in_gb, 5)
      workspace_id         = try(local.env_config.app_service.insights.workspace_id, var.config.global.app_service.insights.workspace_id, null)
      config_content       = try(local.env_config.app_service.insights.config_content, var.config.global.app_service.insights.config_content, null)
    }

    identity_ids = concat(try(var.config.global.app_service.identity_ids, []), try(local.env_config.app_service.identity_ids, [])) // Only needed for backwards compatibility

    identity = {
      type         = try(local.env_config.app_service.identity.type, var.config.global.app_service.identity.type, "UserAssigned")
      identity_ids = concat(try(var.config.global.app_service.identity.identity_ids, []), try(local.env_config.app_service.identity.identity_ids, []))
    }

    ip_restrictions = [ for i, v in concat(try(var.config.global.app_service.ip_restrictions, []), try(local.env_config.app_service.ip_restrictions, [])) : merge(
      {
        action                    = null
        headers                   = null
        name                      = null
        priority                  = (i + 1) * 100
        ip_address                = null
        service_tag               = null
        virtual_network_subnet_id = null
      },
      v
    ) ]

    site_config = merge(
      {
        always_on                         = true
        ftps_state                        = "Disabled"
        health_check_path                 = null
        health_check_eviction_time_in_min = null
        use_32_bit_worker                 = false
        vnet_integration_subnet           = null
        vnet_route_all_enabled            = can(try(local.env_config.app_service.site_config.vnet_integration_subnet, var.config.global.app_service.site_config.vnet_integration_subnet))

        application_stack = {
          java_version           = 11
          java_container         = "JAVA"
          java_container_version = "SE"
        }
      },
      try(var.config.global.app_service.site_config, {}),
      try(local.env_config.app_service.site_config, {})
    )

    app_settings = merge(
      try(var.config.global.app_service.app_settings, {}),
      try(local.env_config.app_service.app_settings, {})
    )

    hybrid_connections = merge(
      try(var.config.global.app_service.hybrid_connections, {}),
      try(local.env_config.app_service.hybrid_connections, {})
    )

    database = {
      server_id       = try(local.env_config.database.server_id, var.config.global.database.server_id, null) // Only needed for backwards compatibility
      server_fqdn     = try(local.env_config.database.server_fqdn, var.config.global.database.server_fqdn, null)
      server_port     = try(local.env_config.database.server_port, var.config.global.database.server_port, 1433)
      name            = try(local.env_config.database.name, var.config.global.database.name, var.config.global.name)
      jdbc_template   = try(local.env_config.database.jdbc_template, var.config.global.database.jdbc_template, "jdbc:sqlserver://%s:%s;database=%s;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;authentication=ActiveDirectoryMSI")
      jdbc_properties = try(
        merge(try(var.config.global.database.jdbc_properties, {}), try(local.env_config.database.jdbc_properties, {})),
        { for s in concat(try(var.config.global.database.jdbc_properties, []), try(local.env_config.database.jdbc_properties, [])) : split("=", s)[0] => split("=", s)[1] } // Only needed for backwards compatibility
      )
    }
  }

  database_server_fqdn     = try(coalesce(local.config.database.server_fqdn, try("${split("/", local.config.database.server_id)[8]}.database.windows.net", null)), null) // Only needed for backwards compatibility
  database_jdbc_basestring = try(format(local.config.database.jdbc_template, local.database_server_fqdn, local.config.database.server_port, local.config.database.name), null)
  database_jdbc_string     = try(join(";", concat([local.database_jdbc_basestring], [ for k, v in local.config.database.jdbc_properties : "${k}=${v}" ])), null)
}

resource "azurecaf_name" "service_plan" {
  name          = local.config.name
  resource_type = "azurerm_app_service_plan"
  suffixes      = [var.environment]
}

resource "azurerm_service_plan" "this" {
  name                   = azurecaf_name.service_plan.result
  resource_group_name    = var.resource_group
  location               = local.config.location
  tags                   = local.config.tags
  os_type                = local.config.os_type
  sku_name               = local.config.sku_name
  worker_count           = local.config.worker_count
  zone_balancing_enabled = local.config.zone_balancing_enabled
}

resource "azurecaf_name" "application_insights" {
  count = length(local.config.insights.workspace_id[*])

  name          = local.config.name
  resource_type = "azurerm_application_insights"
  suffixes      = [var.environment]
}

resource "azurerm_application_insights" "this" {
  count = length(azurecaf_name.application_insights)

  name                 = azurecaf_name.application_insights.0.result
  resource_group_name  = var.resource_group
  location             = local.config.location
  tags                 = local.config.tags
  application_type     = local.config.type == "WebApp" ? local.config.insights.application_type : "web"
  daily_data_cap_in_gb = local.config.insights.daily_data_cap_in_gb
  disable_ip_masking   = local.config.insights.disable_ip_masking
  workspace_id         = local.config.insights.workspace_id
}

resource "azurecaf_name" "app_service" {
  name          = local.config.name
  resource_type = local.config.type == "WebApp" ? "azurerm_app_service" : "azurerm_function_app"
  suffixes      = [var.environment]
}

resource "azurerm_linux_web_app" "this" {
  count = local.config.os_type == "Linux" && local.config.type == "WebApp" ? 1 : 0

  name                = azurecaf_name.app_service.result
  resource_group_name = var.resource_group
  location            = local.config.location
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = local.config.https_only
  tags                = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = length(concat(local.config.identity.identity_ids, local.config.identity_ids)) == 0 ? "SystemAssigned" : local.config.identity.type
      identity_ids = concat(local.config.identity.identity_ids, local.config.identity_ids)
    }
  }

  site_config {
    always_on                         = local.config.site_config.always_on
    ftps_state                        = local.config.site_config.ftps_state
    health_check_path                 = local.config.site_config.health_check_path
    health_check_eviction_time_in_min = local.config.site_config.health_check_eviction_time_in_min
    use_32_bit_worker                 = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled            = local.config.site_config.vnet_route_all_enabled

    dynamic "application_stack" {
      for_each = local.config.site_config.application_stack[*]

      content {
        java_version        = application_stack.value.java_version
        java_server         = application_stack.value.java_server
        java_server_version = application_stack.value.java_server_version
      }
    }

    ip_restriction = local.config.ip_restrictions
  }

  app_settings = merge(
    {
      "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
      "SERVER_SERVLET_CONTEXT_PATH"         = "/"
      "SPRING_DATASOURCE_URL"               = local.database_jdbc_string

      // Monitoring with Azure Application Insights
      "APPLICATIONINSIGHTS_CONNECTION_STRING"           = try(azurerm_application_insights.this.0.connection_string, null)
      "APPINSIGHTS_PROFILERFEATURE_VERSION"             = "1.0.0"
      "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"             = "1.0.0"
      "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"       = local.config.insights.config_content != null ? jsonencode(local.config.insights.config_content) : null
      "ApplicationInsightsAgent_EXTENSION_VERSION"      = "~2"
      "DiagnosticServices_EXTENSION_VERSION"            = "~3"
      "InstrumentationEngine_EXTENSION_VERSION"         = "disabled"
      "SnapshotDebugger_EXTENSION_VERSION"              = "disabled"
      "XDT_MicrosoftApplicationInsights_BaseExtensions" = "disabled"
      "XDT_MicrosoftApplicationInsights_Java"           = "1"
      "XDT_MicrosoftApplicationInsights_Mode"           = "recommended"
      "XDT_MicrosoftApplicationInsights_NodeJS"         = "1"
      "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"
    },
    local.config.app_settings
  )
}

resource "azurerm_windows_web_app" "this" {
  count = local.config.os_type == "Windows" && local.config.type == "WebApp" ? 1 : 0

  name                = azurecaf_name.app_service.result
  resource_group_name = var.resource_group
  location            = local.config.location
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = local.config.https_only
  tags                = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = length(concat(local.config.identity.identity_ids, local.config.identity_ids)) == 0 ? "SystemAssigned" : local.config.identity.type
      identity_ids = concat(local.config.identity.identity_ids, local.config.identity_ids)
    }
  }

  site_config {
    always_on                         = local.config.site_config.always_on
    ftps_state                        = local.config.site_config.ftps_state
    health_check_path                 = local.config.site_config.health_check_path
    health_check_eviction_time_in_min = local.config.site_config.health_check_eviction_time_in_min
    use_32_bit_worker                 = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled            = local.config.site_config.vnet_route_all_enabled

    dynamic "application_stack" {
      for_each = local.config.site_config.application_stack[*]

      content {
        current_stack          = lookup(application_stack.value, "current_stack", application_stack.value.java_version != null ? "java" : null)
        java_version           = application_stack.value.java_version
        java_container         = application_stack.value.java_container
        java_container_version = application_stack.value.java_container_version
      }
    }

    ip_restriction = local.config.ip_restrictions
  }

  app_settings = merge(
    {
      "SERVER_SERVLET_CONTEXT_PATH"         = "/"
      "SPRING_PROFILES_ACTIVE"              = var.environment
      "SPRING_DATASOURCE_URL"               = local.database_jdbc_string

      // Monitoring with Azure Application Insights
      "APPLICATIONINSIGHTS_CONNECTION_STRING"           = try(azurerm_application_insights.this.0.connection_string, null)
      "APPINSIGHTS_PROFILERFEATURE_VERSION"             = "1.0.0"
      "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"             = "1.0.0"
      "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"       = local.config.insights.config_content != null ? jsonencode(local.config.insights.config_content) : null
      "ApplicationInsightsAgent_EXTENSION_VERSION"      = "~2"
      "DiagnosticServices_EXTENSION_VERSION"            = "~3"
      "InstrumentationEngine_EXTENSION_VERSION"         = "disabled"
      "SnapshotDebugger_EXTENSION_VERSION"              = "disabled"
      "XDT_MicrosoftApplicationInsights_BaseExtensions" = "disabled"
      "XDT_MicrosoftApplicationInsights_Java"           = "1"
      "XDT_MicrosoftApplicationInsights_Mode"           = "recommended"
      "XDT_MicrosoftApplicationInsights_NodeJS"         = "1"
      "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"
    },
    local.config.app_settings
  )

  lifecycle {
    ignore_changes = [
      # Temporary fix to allow for manually setting java version 17 until this is fixed in the azurerm provider.
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/17144
      site_config["application_stack"],
    ]
  }
}

resource "azurecaf_name" "storage_account" {
  count = local.config.type == "FunctionApp" ? 1 : 0

  name          = local.config.name
  resource_type = "azurerm_storage_account"
  random_length = 10
}

resource "azurerm_storage_account" "this" {
  count = length(azurecaf_name.storage_account)

  name                     = azurecaf_name.storage_account.0.result
  resource_group_name      = var.resource_group
  location                 = local.config.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.config.tags
}

resource "azurerm_linux_function_app" "this" {
  count = local.config.os_type == "Linux" && local.config.type == "FunctionApp" ? 1 : 0

  name                        = azurecaf_name.app_service.result
  resource_group_name         = var.resource_group
  location                    = local.config.location
  service_plan_id             = azurerm_service_plan.this.id
  storage_account_name        = azurerm_storage_account.this.0.name
  storage_account_access_key  = azurerm_storage_account.this.0.primary_access_key
  functions_extension_version = "~3"
  https_only                  = local.config.https_only
  tags                        = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = length(concat(local.config.identity.identity_ids, local.config.identity_ids)) == 0 ? "SystemAssigned" : local.config.identity.type
      identity_ids = concat(local.config.identity.identity_ids, local.config.identity_ids)
    }
  }

  site_config {
    always_on                              = local.config.site_config.always_on
    ftps_state                             = local.config.site_config.ftps_state
    health_check_path                      = local.config.site_config.health_check_path
    health_check_eviction_time_in_min      = local.config.site_config.health_check_eviction_time_in_min
    use_32_bit_worker                      = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                 = local.config.site_config.vnet_route_all_enabled
    application_insights_connection_string = try(azurerm_application_insights.this.0.connection_string, null)
    application_insights_key               = try(azurerm_application_insights.this.0.instrumentation_key, null)

    dynamic "application_stack" {
      for_each = local.config.site_config.application_stack[*]

      content {
        java_version = application_stack.value.java_version
      }
    }

    ip_restriction = local.config.ip_restrictions
  }

  app_settings = merge(
    {
      "SPRING_PROFILES_ACTIVE" = var.environment
      "SPRING_DATASOURCE_URL"  = local.database_jdbc_string
    },
    local.config.app_settings
  )
}

resource "azurerm_windows_function_app" "this" {
  count = local.config.os_type == "Windows" && local.config.type == "FunctionApp" ? 1 : 0

  name                        = azurecaf_name.app_service.result
  resource_group_name         = var.resource_group
  location                    = local.config.location
  service_plan_id             = azurerm_service_plan.this.id
  storage_account_name        = azurerm_storage_account.this.0.name
  storage_account_access_key  = azurerm_storage_account.this.0.primary_access_key
  functions_extension_version = "~3"
  https_only                  = local.config.https_only
  tags                        = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = length(concat(local.config.identity.identity_ids, local.config.identity_ids)) == 0 ? "SystemAssigned" : local.config.identity.type
      identity_ids = concat(local.config.identity.identity_ids, local.config.identity_ids)
    }
  }

  site_config {
    always_on                              = local.config.site_config.always_on
    ftps_state                             = local.config.site_config.ftps_state
    health_check_path                      = local.config.site_config.health_check_path
    health_check_eviction_time_in_min      = local.config.site_config.health_check_eviction_time_in_min
    use_32_bit_worker                      = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                 = local.config.site_config.vnet_route_all_enabled
    application_insights_connection_string = try(azurerm_application_insights.this.0.connection_string, null)
    application_insights_key               = try(azurerm_application_insights.this.0.instrumentation_key, null)

    dynamic "application_stack" {
      for_each = local.config.site_config.application_stack[*]

      content {
        java_version = application_stack.value.java_version
      }
    }

    ip_restriction = local.config.ip_restrictions
  }

  app_settings = merge(
    {
      "SPRING_PROFILES_ACTIVE" = var.environment
      "SPRING_DATASOURCE_URL"  = local.database_jdbc_string
    },
    local.config.app_settings
  )
}

resource "azurerm_app_service_virtual_network_swift_connection" "this" {
  count = local.config.site_config.vnet_integration_subnet != null ? 1 : 0

  app_service_id = try(azurerm_windows_web_app.this.0, azurerm_linux_web_app.this.0, azurerm_windows_function_app.this.0, azurerm_linux_function_app.this.0).id
  subnet_id      = lookup(var.subnet_ids, local.config.site_config.vnet_integration_subnet)
}
