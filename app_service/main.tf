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
  // TODO: Varför inte zone redundance?

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
  // TODO: Retention period på dessa? Default är 90 dagar, duger de enligt era SLA:er? Eller sugs loggar ut och ner i "cold storage" där ni kan ha dem längre
}

resource "azurecaf_name" "app_service" {
  name          = var.settings.name
  resource_type = var.is_function ? "azurerm_function_app" : "azurerm_app_service"
  suffixes      = [var.settings.environment]
}
// TODO: Om vi ska skapa en azurefunction  eller inte kör detta block
// ------------------------
resource "azurerm_app_service" "this" {
  count = var.is_function ? 0 : 1

  name                = azurecaf_name.app_service.result
  resource_group_name = azurerm_app_service_plan.this.resource_group_name
  location            = azurerm_app_service_plan.this.location
  app_service_plan_id = azurerm_app_service_plan.this.id
  https_only          = true
  tags                = var.settings.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    ftps_state             = "Disabled"
    java_version           = lookup(var.site_config, "java_version", null)
    java_container         = lookup(var.site_config, "java_container", null)
    java_container_version = lookup(var.site_config, "java_container_version", null)
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
// TODO: Else..... detta block
// ---------------
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
  account_tier             = "Standard" // TODO: Hade gjort dessa till variabler, så man kan ha passande conf i test vs prod
  account_replication_type = "LRS"  // TODO: Hade gjort dessa till variabler, så man kan ha passande conf i test vs prod
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
  https_only                 = true
  tags                       = var.settings.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    ftps_state             = "Disabled"
    java_version           = lookup(var.site_config, "java_version", null)
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

resource "azurerm_app_service_virtual_network_swift_connection" "this" {
  count = length(var.subnet_id[*])

  app_service_id = (var.is_function ? azurerm_function_app.this.0.id : azurerm_app_service.this.0.id)
  subnet_id      = var.subnet_id
}
