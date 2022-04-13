resource "azurecaf_name" "app_service_plan" {
  name          = var.settings.name
  resource_type = "azurerm_app_service_plan"
  suffixes      = [var.settings.environment]
}

resource "azurerm_app_service_plan" "this" {
  name                = azurecaf_name.app_service_plan.result
  resource_group_name = var.settings.resource_group
  location            = var.settings.location
  tags                = var.settings.tags
  kind                = var.kind
  reserved            = var.kind == "Linux" ? true : false
  zone_redundant      = var.zone_redundant

  sku {
    tier     = var.sku.tier
    size     = var.sku.size
    capacity = var.sku.capacity
  }
}

resource "azurecaf_name" "application_insights" {
  count = length(var.insights_workspace_id[*])

  name          = var.settings.name
  resource_type = "azurerm_application_insights"
  suffixes      = [var.settings.environment]
}

resource "azurerm_application_insights" "this" {
  count = length(azurecaf_name.application_insights)

  name                 = azurecaf_name.application_insights.0.result
  resource_group_name  = azurerm_app_service_plan.this.resource_group_name
  location             = azurerm_app_service_plan.this.location
  workspace_id         = var.insights_workspace_id
  daily_data_cap_in_gb = var.insights_daily_data_cap_in_gb
  application_type     = var.is_function ? "web" : var.insights_type
  tags                 = var.settings.tags
  disable_ip_masking   = var.insights_disable_ip_masking
}

resource "azurecaf_name" "app_service" {
  name          = var.settings.name
  resource_type = var.is_function ? "azurerm_function_app" : "azurerm_app_service"
  suffixes      = [var.settings.environment]
}

resource "azurerm_app_service" "this" {
  count = var.is_function ? 0 : 1

  name                = azurecaf_name.app_service.result
  resource_group_name = azurerm_app_service_plan.this.resource_group_name
  location            = azurerm_app_service_plan.this.location
  app_service_plan_id = azurerm_app_service_plan.this.id
  https_only          = var.https_only
  tags                = var.settings.tags

  identity {
    type         = length(var.identity_ids) == 0 ? "SystemAssigned" : "UserAssigned"
    identity_ids = var.identity_ids
  }

  site_config {
    always_on              = lookup(var.site_config, "always_on", true)
    ftps_state             = lookup(var.site_config, "ftps_state", "Disabled")
    health_check_path      = lookup(var.site_config, "health_check_path", null)
    java_version           = lookup(var.site_config, "java_version", "11")
    java_container         = lookup(var.site_config, "java_container", "JAVA")
    java_container_version = lookup(var.site_config, "java_container_version", "SE")
    linux_fx_version       = lookup(var.site_config, "linux_fx_version", null)
    vnet_route_all_enabled = length(var.subnet_id[*]) == 1

    ip_restriction = [ for i, v in var.ip_restrictions : merge(
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
  }

  app_settings = merge(
    {
      "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"

      // Monitoring with Azure Application Insights
      "APPINSIGHTS_INSTRUMENTATIONKEY"                  = try(azurerm_application_insights.this.0.instrumentation_key, "")
      "APPINSIGHTS_PROFILERFEATURE_VERSION"             = "1.0.0"
      "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"             = "1.0.0"
      "APPLICATIONINSIGHTS_CONNECTION_STRING"           = try(azurerm_application_insights.this.0.connection_string, "")
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
    var.app_settings
  )
}

resource "azurecaf_name" "storage_account" {
  count = var.is_function ? 1 : 0

  name          = var.settings.name
  resource_type = "azurerm_storage_account"
  random_length = 10
}

resource "azurerm_storage_account" "this" {
  count = var.is_function ? 1 : 0

  name                     = azurecaf_name.storage_account.0.result
  resource_group_name      = azurerm_app_service_plan.this.resource_group_name
  location                 = azurerm_app_service_plan.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.settings.tags
}

resource "azurerm_function_app" "this" {
  count = var.is_function ? 1 : 0

  name                       = azurecaf_name.app_service.result
  resource_group_name        = azurerm_app_service_plan.this.resource_group_name
  location                   = azurerm_app_service_plan.this.location
  app_service_plan_id        = azurerm_app_service_plan.this.id
  storage_account_name       = azurerm_storage_account.this.0.name
  storage_account_access_key = azurerm_storage_account.this.0.primary_access_key
  version                    = "~3"
  https_only                 = var.https_only
  tags                       = var.settings.tags

  identity {
    type         = length(var.identity_ids) == 0 ? "SystemAssigned" : "UserAssigned"
    identity_ids = var.identity_ids
  }

  site_config {
    always_on              = lookup(var.site_config, "always_on", true)
    ftps_state             = lookup(var.site_config, "ftps_state", "Disabled")
    health_check_path      = lookup(var.site_config, "health_check_path", null)
    java_version           = lookup(var.site_config, "java_version", "11")
    linux_fx_version       = lookup(var.site_config, "linux_fx_version", null)
    vnet_route_all_enabled = length(var.subnet_id[*]) == 1

    ip_restriction = [ for i, v in var.ip_restrictions : merge(
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
  }

  app_settings = merge(
    {
      // Monitoring with Azure Application Insights
      "APPINSIGHTS_INSTRUMENTATIONKEY"                  = try(azurerm_application_insights.this.0.instrumentation_key, "")
      "APPLICATIONINSIGHTS_CONNECTION_STRING"           = try(azurerm_application_insights.this.0.connection_string, "")
    },
    var.app_settings
  )
}

locals {
  app_service_id = (var.is_function ? azurerm_function_app.this.0.id : azurerm_app_service.this.0.id)
}

resource "azurerm_app_service_virtual_network_swift_connection" "this" {
  count = length(var.subnet_id[*])

  app_service_id = local.app_service_id
  subnet_id      = var.subnet_id
}

data "azurerm_monitor_diagnostic_categories" "this" {
  count = try(length(var.diagnostic_categories.logs), 1) + try(length(var.diagnostic_categories.metrics), 1) > 0 ? length(var.insights_workspace_id[*]) : 0

  resource_id = local.app_service_id
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = length(data.azurerm_monitor_diagnostic_categories.this)

  name                       = "SendToLogAnalytics"
  target_resource_id         = local.app_service_id
  log_analytics_workspace_id = var.insights_workspace_id

  dynamic "log" {
    for_each = coalesce(var.diagnostic_categories.logs, data.azurerm_monitor_diagnostic_categories.this.0.logs)

    content {
      category = log.value

      retention_policy {
        days    = 0
        enabled = false
      }
    }
  }

  dynamic "metric" {
    for_each = coalesce(var.diagnostic_categories.metrics, data.azurerm_monitor_diagnostic_categories.this.0.metrics)

    content {
      category = metric.value

      retention_policy {
        days    = 0
        enabled = false
      }
    }
  }
}
