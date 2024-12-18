locals {
  flex_count = local.config.os_type == "Linux" && local.config.type == "FunctionApp" && try(startswith(local.config.sku_name, "FC"), false) ? 1 : 0
}

resource "azurecaf_name" "flex_storage_container" {
  count = local.flex_count

  name          = local.config.name
  resource_type = "azurerm_function_app"
  prefixes      = ["app-package"]
  suffixes      = [var.environment]
}

resource "azurerm_storage_container" "this" {
  count = local.flex_count

  name               = azurecaf_name.flex_storage_container.0.result
  storage_account_id = var.storage_account.id
}

locals {
  flex_app_settings = merge(
    {
      "AzureWebJobsStorage"                   = try(startswith(local.config.identity.type, "SystemAssigned"), false) ? null : local.config.storage_account_connection_string
      "AzureWebJobsStorage__accountName"      = try(startswith(local.config.identity.type, "SystemAssigned"), false) ? local.config.storage_account_name : null
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = try(azurerm_application_insights.this.0.connection_string, var.app_service.application_insights_connection_string, null)
    },
    local.config.app_settings
  )
}

resource "azapi_resource" "flex_function" {
  type = "Microsoft.Web/sites@2024-04-01"

  count = local.flex_count

  location  = local.config.location
  name      = azurecaf_name.app_service[0].result
  parent_id = var.resource_group.id

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? [] : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  tags = local.config.tags

  body = {
    kind = "functionapp,linux"
    properties = {
      clientCertEnabled        = local.config.client_certificate_mode != null
      clientCertExclusionPaths = local.config.client_certificate_exclusion_paths
      clientCertMode           = local.config.client_certificate_mode
      enabled                  = true
      functionAppConfig = {
        deployment = {
          storage = {
            type  = "blobContainer"
            value = format("%s%s", var.storage_account.primary_blob_endpoint, azurerm_storage_container.this[0].name)
            authentication = {
              storageAccountConnectionStringName = try(startswith(local.config.identity.type, "SystemAssigned"), false) ? null : "DEPLOYMENT_STORAGE_CONNECTION_STRING"
              type                               = try(startswith(local.config.identity.type, "SystemAssigned"), false) ? "SystemAssignedIdentity" : "StorageAccountConnectionString"
              userAssignedIdentityResourceId     = null
            }
          }
        }
        scaleAndConcurrency = {
          alwaysReady          = null
          instanceMemoryMB     = 2048
          maximumInstanceCount = 100
          triggers             = null
        }
        runtime = {
          name    = "java"
          version = "17"
        }
      }
      httpsOnly           = true
      publicNetworkAccess = local.config.public_network_access_enabled == false ? "Disabled" : "Enabled"
      serverFarmId        = replace(local.config.service_plan_id != null ? local.config.service_plan_id : azurerm_service_plan.this.0.id, "serverFarms", "serverfarms")
      siteConfig = {
        appSettings        = [for k, v in local.flex_app_settings : { name = k, value = tostring(v) } if v != null]
        healthCheckPath    = local.config.site_config.health_check_path
        http20Enabled      = false
        httpLoggingEnabled = null
        minTlsCipherSuite  = null
        minTlsVersion      = local.config.site_config.minimum_tls_version
      }
      virtualNetworkSubnetId = local.config.virtual_network_subnet_id
      vnetRouteAllEnabled    = true
    }
  }

  response_export_values = ["properties.defaultHostName"]

  lifecycle {
    ignore_changes = [
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }
}

resource "azapi_update_resource" "web_sites_config" {
  type = "Microsoft.Web/sites/config@2024-04-01"

  count = min(local.flex_count, length(local.config.ip_restrictions))

  name      = "web"
  parent_id = azapi_resource.flex_function[0].id
  body = {
    properties = {
      ipSecurityRestrictions = concat(
        [
          for i in local.config.ip_restrictions : {
            action               = coalesce(i.action, "Allow")
            description          = null
            headers              = i.headers
            ipAddress            = i.ip_address
            name                 = i.name
            priority             = i.priority
            subnetMask           = null
            vnetSubnetResourceId = i.virtual_network_subnet_id
          }
        ],
        [
          {
            action      = "Deny"
            description = "Deny all access"
            ipAddress   = "Any"
            name        = "Deny all"
            priority    = 2147483647
          }
        ]
      )
      ipSecurityRestrictionsDefaultAction = "Deny"
    }
  }
}

resource "azurerm_role_assignment" "func" {
  count = local.flex_count

  principal_id         = azapi_resource.flex_function[0].identity[0].principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = var.storage_account.id
}
