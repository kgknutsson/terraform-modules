locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name                = var.config.global.name
    location            = var.resource_group.location
    resource_group_name = var.resource_group.name

    naming = {
      for i in ["azurerm_application_insights"] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = compact([var.environment])
          random_length = null
          use_slug      = null
        },
        try(lookup(var.config.global.app_service.naming, i), {}),
        try(lookup(local.env_config.app_service.naming, i), {})
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
      try(var.config.global.app_service.tags, {}),
      try(local.env_config.app_service.tags, {})
    )

    type                                           = try(local.env_config.app_service.type, var.config.global.app_service.type, null) // WebApp, FunctionApp
    service_plan_id                                = try(local.env_config.app_service.service_plan_id, var.config.global.app_service.service_plan_id, var.app_service.service_plan_id, null)
    os_type                                        = try(local.env_config.app_service.os_type, var.config.global.app_service.os_type, var.app_service.service_plan_os_type, "Linux") // Linux or Windows
    sku_name                                       = try(local.env_config.app_service.sku_name, var.config.global.app_service.sku_name, null)
    worker_count                                   = try(local.env_config.app_service.worker_count, var.config.global.app_service.worker_count, null)
    per_site_scaling_enabled                       = try(local.env_config.app_service.per_site_scaling_enabled, var.config.global.app_service.per_site_scaling_enabled, false)
    storage_account_name                           = try(local.env_config.app_service.storage_account_name, var.config.global.app_service.storage_account_name, var.storage_account.name, null)
    storage_account_access_key                     = try(local.env_config.app_service.storage_account_access_key, var.config.global.app_service.storage_account_access_key, var.storage_account.primary_access_key, null)
    functions_extension_version                    = try(local.env_config.app_service.functions_extension_version, var.config.global.app_service.functions_extension_version, "~4")
    https_only                                     = try(local.env_config.app_service.https_only, var.config.global.app_service.https_only, true)
    builtin_logging_enabled                        = try(local.env_config.app_service.builtin_logging_enabled, var.config.global.app_service.builtin_logging_enabled, false)
    client_certificate_mode                        = try(local.env_config.app_service.client_certificate_mode, var.config.global.app_service.client_certificate_mode, "Optional") // Required, Optional or OptionalInteractiveUser
    client_certificate_exclusion_paths             = join(";", concat(try(local.env_config.app_service.client_certificate_exclusion_paths, []), try(var.config.global.app_service.client_certificate_exclusion_paths, [])))
    public_network_access_enabled                  = try(local.env_config.app_service.public_network_access_enabled, var.config.global.app_service.public_network_access_enabled, null)
    ftp_publish_basic_authentication_enabled       = try(local.env_config.app_service.ftp_publish_basic_authentication_enabled, var.config.global.app_service.ftp_publish_basic_authentication_enabled, false)
    webdeploy_publish_basic_authentication_enabled = try(local.env_config.app_service.webdeploy_publish_basic_authentication_enabled, var.config.global.app_service.webdeploy_publish_basic_authentication_enabled, false)
    zip_deploy_file                                = try(local.env_config.app_service.zip_deploy_file, var.config.global.app_service.zip_deploy_file, null)
    zone_balancing_enabled                         = try(local.env_config.app_service.zone_balancing_enabled, var.config.global.app_service.zone_balancing_enabled, false)
    acr_id                                         = try(local.env_config.app_service.acr_id, var.config.global.app_service.acr_id, null)

    metric_alerts = {
      enabled          = try(local.env_config.app_service.metric_alerts.enabled, var.config.global.app_service.metric_alerts.enabled, true)
      action_group_ids = concat(try(local.env_config.app_service.metric_alerts.action_group_ids, []), try(var.config.global.app_service.metric_alerts.action_group_ids, []))
    }

    virtual_network_subnet_id = try(
      var.virtual_network.subnet_id_map[local.env_config.app_service.virtual_network_subnet_id],
      local.env_config.app_service.virtual_network_subnet_id,
      var.virtual_network.subnet_id_map[var.config.global.app_service.virtual_network_subnet_id],
      var.config.global.app_service.virtual_network_subnet_id,
      var.app_service.virtual_network_subnet_id,
      null
    )

    monitor_diagnostic_setting = {
      enabled_logs = [
        for i in coalescelist(
          concat(
            try(flatten([var.config.global.app_service.monitor_diagnostic_setting.enabled_logs]),  []),
            try(flatten([local.env_config.app_service.monitor_diagnostic_setting.enabled_logs]), [])
          ),
          [
            try(local.env_config.app_service.type, var.config.global.app_service.type, null) == "FunctionApp" ? { category = "FunctionAppLogs" } : { category_group = "allLogs" }
          ]
        )
        : i if i != null
      ]
      metrics = [
        for i in coalescelist(
          concat(
            try(flatten([var.config.global.app_service.monitor_diagnostic_setting.metrics]),  []),
            try(flatten([local.env_config.app_service.monitor_diagnostic_setting.metrics]), [])
          ),
          [
            { category = "AllMetrics" }
          ]
        )
        : i if i != null
      ]
    }

    insights = {
      application_type     = try(local.env_config.app_service.insights.application_type, var.config.global.app_service.insights.application_type, "java")
      disable_ip_masking   = try(local.env_config.app_service.insights.disable_ip_masking, var.config.global.app_service.insights.disable_ip_masking, false)
      daily_data_cap_in_gb = try(local.env_config.app_service.insights.daily_data_cap_in_gb, var.config.global.app_service.insights.daily_data_cap_in_gb, 5)
      sampling_percentage  = try(local.env_config.app_service.insights.sampling_percentage, var.config.global.app_service.insights.sampling_percentage, null)
      workspace_id         = try(local.env_config.app_service.insights.workspace_id, var.config.global.app_service.insights.workspace_id, var.app_service.application_insights_workspace_id, null)
      config_content       = try(local.env_config.app_service.insights.config_content, var.config.global.app_service.insights.config_content, null)
    }

    identity = {
      type         = try(local.env_config.app_service.identity.type, var.config.global.app_service.identity.type, "SystemAssigned")
      identity_ids = concat(try(var.config.global.app_service.identity.identity_ids, []), try(local.env_config.app_service.identity.identity_ids, []))
    }

    ip_restrictions = [ for i, v in concat(try(var.config.global.app_service.ip_restrictions, []), try(local.env_config.app_service.ip_restrictions, [])) : merge(
      {
        action                    = null
        name                      = null
        priority                  = (i + 1) * 100
        ip_address                = null
        service_tag               = null
        virtual_network_subnet_id = null
      },
      v,
      {
        headers = try(v.headers, null) != null ? [
          merge(
            {
              x_azure_fdid      = []
              x_fd_health_probe = []
              x_forwarded_for   = []
              x_forwarded_host  = []
            },
            { for x, y in v.headers : lower(replace(x, "-", "_")) => [y]}
          )
        ] : null
      }
    ) ]

    scm_ip_restrictions = [ for i, v in concat(try(var.config.global.app_service.scm_ip_restrictions, []), try(local.env_config.app_service.scm_ip_restrictions, [])) : merge(
      {
        action                    = null
        name                      = null
        priority                  = (i + 1) * 100
        ip_address                = null
        service_tag               = null
        virtual_network_subnet_id = null
      },
      v,
      {
        headers = try(v.headers, null) != null ? [
          merge(
            {
              x_azure_fdid      = []
              x_fd_health_probe = []
              x_forwarded_for   = []
              x_forwarded_host  = []
            },
            { for x, y in v.headers : lower(replace(x, "-", "_")) => [y]}
          )
        ] : null
      }
    ) ]

    service_connections = {
      for k in setunion(
        try(keys(var.config.global.app_service.service_connections), []),
        try(keys(local.env_config.app_service.service_connections), [])
      ) : k => merge(
        {
          authentication = {
            type            = "systemAssignedIdentity" // systemAssignedIdentity or userAssignedIdentity
            client_id       = null
            subscription_id = null
          }
        },
        try(var.config.global.app_service.service_connections[k], {}),
        try(local.env_config.app_service.service_connections[k], {})
      )
    }

    site_config = merge(
      {
        always_on                                     = true
        ftps_state                                    = "Disabled"
        health_check_path                             = null
        health_check_eviction_time_in_min             = 10
        auto_heal_setting                             = null
        container_registry_managed_identity_client_id = null
        container_registry_use_managed_identity       = null
        minimum_tls_version                           = null
        scm_minimum_tls_version                       = null
        scm_use_main_ip_restriction                   = false
        use_32_bit_worker                             = false
        worker_count                                  = try(local.env_config.app_service.per_site_scaling_enabled, var.config.global.app_service.per_site_scaling_enabled, false) ? try(local.env_config.app_service.worker_count, var.config.global.app_service.worker_count, null) : null

        vnet_route_all_enabled = try(
          var.virtual_network.subnet_id_map[local.env_config.app_service.virtual_network_subnet_id],
          local.env_config.app_service.virtual_network_subnet_id,
          var.virtual_network.subnet_id_map[var.config.global.app_service.virtual_network_subnet_id],
          var.config.global.app_service.virtual_network_subnet_id,
          var.app_service.virtual_network_subnet_id,
          null
        ) != null

        cors = null
      },
      try(var.config.global.app_service.site_config, {}),
      try(local.env_config.app_service.site_config, {}),
      {
        application_stack = merge(
          {
            docker                      = []
            docker_image_name           = null
            docker_registry_url         = null
            docker_registry_username    = null
            docker_registry_password    = null
            dotnet_version              = null
            use_dotnet_isolated_runtime = null
            go_version                  = null
            java_version                = null
            node_version                = null
            php_version                 = null
            python                      = null
            python_version              = null
            powershell_core_version     = null
            ruby_version                = null
          },
          try(
            local.env_config.app_service.site_config.application_stack,
            var.config.global.app_service.site_config.application_stack,
            {
              java_version   = 17
            }
          )
        )
      }
    )

    app_settings = merge(
      try(var.config.global.app_service.app_settings, {}),
      try(local.env_config.app_service.app_settings, {})
    )

    sticky_settings = {
      app_setting_names       = try(coalescelist(concat(try(var.config.global.app_service.sticky_settings.app_setting_names, []), try(local.env_config.app_service.sticky_settings.app_setting_names, []))), null)
      connection_string_names = try(coalescelist(concat(try(var.config.global.app_service.sticky_settings.connection_string_names, []), try(local.env_config.app_service.sticky_settings.connection_string_names, []))), null)
    }

    deployment_slots = {
      for k in setunion(
        try(keys(var.config.global.app_service.deployment_slots), []),
        try(keys(local.env_config.app_service.deployment_slots), [])
      ) : k => merge(
        try(var.config.global.app_service.deployment_slots[k], {}),
        try(local.env_config.app_service.deployment_slots[k], {}),
        {
          for i in ["app_settings", "site_config"] : i => merge(
            try(var.config.global.app_service.deployment_slots[k][i], {}),
            try(local.env_config.app_service.deployment_slots[k][i], {}),
          )
        }
      )
    }

    hybrid_connections = merge(
      try(var.config.global.app_service.hybrid_connections, {}),
      try(local.env_config.app_service.hybrid_connections, {})
    )

    database = {
      server_fqdn     = try(local.env_config.database.server_fqdn, var.config.global.database.server_fqdn, null)
      server_port     = try(local.env_config.database.server_port, var.config.global.database.server_port, 1433)
      name            = try(local.env_config.database.name, var.config.global.database.name, var.config.global.name)
      jdbc_template   = try(local.env_config.database.jdbc_template, var.config.global.database.jdbc_template, "jdbc:sqlserver://%s:%s;database=%s;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;authentication=ActiveDirectoryMSI")
      jdbc_properties = merge(try(var.config.global.database.jdbc_properties, {}), try(local.env_config.database.jdbc_properties, {}))
    }
  }

  appinsights_connection_string = try(azurerm_application_insights.this.0.connection_string, var.app_service.application_insights_connection_string, null)

  appinsights_app_settings = local.config.type == "WebApp" && local.appinsights_connection_string != null ? merge(
    {
      "APPLICATIONINSIGHTS_CONNECTION_STRING"      = local.appinsights_connection_string
      "ApplicationInsightsAgent_EXTENSION_VERSION" = { Linux = "~3", Windows = "~2"}[local.config.os_type]
    },
    yamldecode(file("${path.module}/appinsights_defaults.yml"))
  ) : {}

  app_settings = merge(
    local.appinsights_app_settings,
    local.config.type == "FunctionApp" && local.appinsights_connection_string != null ? {
      "APPLICATIONINSIGHTS_ENABLE_AGENT" = true
    } : {},
    local.config.site_config.application_stack.java_version != null ? {
      "SERVER_SERVLET_CONTEXT_PATH" = local.config.type == "WebApp" ? "/" : null
      "SPRING_PROFILES_ACTIVE"      = var.environment
      "SPRING_DATASOURCE_URL"       = local.database_jdbc_string
    } : {},
    local.config.os_type == "Linux" && local.config.type == "WebApp" ? {
      "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    } : {},
    local.config.zip_deploy_file != null ? {
      "WEBSITE_RUN_FROM_PACKAGE" = 1
    } : {},
    local.config.app_settings
  )

  database_jdbc_basestring = local.config.database.server_fqdn != null ? format(local.config.database.jdbc_template, local.config.database.server_fqdn, local.config.database.server_port, local.config.database.name) : null
  database_jdbc_string     = try(join(";", concat([local.database_jdbc_basestring], [ for k, v in local.config.database.jdbc_properties : "${k}=${v}" ])), null)

  service_connection_app_settings    = yamldecode(file("${path.module}/service_connection_app_settings.yml"))
  service_connection_sticky_settings = flatten(
    matchkeys(
      values(local.service_connection_app_settings),
      keys(local.service_connection_app_settings),
      [
        for k, v in local.config.service_connections : split("/", v.target_resource_id)[6]
      ]
    )
  )
}

resource "azurecaf_name" "service_plan" {
  count = local.config.sku_name == null ? 0 : 1

  name          = local.config.name
  resource_type = "azurerm_app_service_plan"
  suffixes      = [var.environment]
}

resource "azurerm_service_plan" "this" {
  count = length(azurecaf_name.service_plan)

  name                     = azurecaf_name.service_plan.0.result
  resource_group_name      = local.config.resource_group_name
  location                 = local.config.location
  tags                     = local.config.tags
  os_type                  = local.config.os_type
  sku_name                 = local.config.sku_name
  worker_count             = local.config.worker_count
  per_site_scaling_enabled = local.config.per_site_scaling_enabled
  zone_balancing_enabled   = local.config.zone_balancing_enabled
}

resource "azurecaf_name" "application_insights" {
  count = local.config.insights.workspace_id != null && try(var.app_service.application_insights_connection_string, null) == null ? 1 : 0

  name          = local.config.naming["azurerm_application_insights"].name
  resource_type = "azurerm_application_insights"
  prefixes      = local.config.naming["azurerm_application_insights"].prefixes
  suffixes      = local.config.naming["azurerm_application_insights"].suffixes
  random_length = local.config.naming["azurerm_application_insights"].random_length
  use_slug      = local.config.naming["azurerm_application_insights"].use_slug
}

resource "azurerm_application_insights" "this" {
  count = length(azurecaf_name.application_insights)

  name                 = azurecaf_name.application_insights.0.result
  resource_group_name  = local.config.resource_group_name
  location             = local.config.location
  tags                 = local.config.tags
  application_type     = local.config.insights.application_type
  daily_data_cap_in_gb = local.config.insights.daily_data_cap_in_gb
  disable_ip_masking   = local.config.insights.disable_ip_masking
  sampling_percentage  = local.config.insights.sampling_percentage
  workspace_id         = local.config.insights.workspace_id
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

resource "azurerm_role_assignment" "this" {
  count = min(length(local.config.acr_id[*]), length(azurerm_user_assigned_identity.this))

  scope                            = local.config.acr_id
  role_definition_name             = "ACRPull"
  principal_id                     = azurerm_user_assigned_identity.this.0.principal_id
  skip_service_principal_aad_check = true
}

resource "azurecaf_name" "app_service" {
  count = local.config.type != null ? 1 : 0

  name          = local.config.name
  resource_type = local.config.type == "WebApp" ? "azurerm_app_service" : "azurerm_function_app"
  suffixes      = [var.environment]
}

resource "azurerm_linux_web_app" "this" {
  count = local.config.os_type == "Linux" && local.config.type == "WebApp" ? 1 : 0

  name                                           = azurecaf_name.app_service.0.result
  resource_group_name                            = local.config.resource_group_name
  location                                       = local.config.location
  service_plan_id                                = local.config.service_plan_id != null ? local.config.service_plan_id : azurerm_service_plan.this.0.id
  virtual_network_subnet_id                      = local.config.virtual_network_subnet_id
  https_only                                     = local.config.https_only
  client_certificate_enabled                     = local.config.client_certificate_mode != null
  client_certificate_mode                        = local.config.client_certificate_mode
  client_certificate_exclusion_paths             = local.config.client_certificate_exclusion_paths
  public_network_access_enabled                  = local.config.public_network_access_enabled
  ftp_publish_basic_authentication_enabled       = local.config.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = local.config.webdeploy_publish_basic_authentication_enabled
  zip_deploy_file                                = local.config.zip_deploy_file
  tags                                           = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  site_config {
    always_on                                     = local.config.site_config.always_on
    ftps_state                                    = local.config.site_config.ftps_state
    health_check_path                             = local.config.site_config.health_check_path
    health_check_eviction_time_in_min             = local.config.site_config.health_check_path != null ? local.config.site_config.health_check_eviction_time_in_min : null
    container_registry_managed_identity_client_id = try(coalesce(local.config.site_config.container_registry_managed_identity_client_id, azurerm_user_assigned_identity.this.0.client_id), null)
    container_registry_use_managed_identity       = local.config.site_config.container_registry_use_managed_identity
    minimum_tls_version                           = local.config.site_config.minimum_tls_version
    scm_minimum_tls_version                       = local.config.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction                   = local.config.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                             = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                        = local.config.site_config.vnet_route_all_enabled
    ip_restriction_default_action                 = length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny"
    scm_ip_restriction_default_action             = local.config.site_config.scm_use_main_ip_restriction ? length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny" : length(local.config.scm_ip_restrictions) == 0 ? "Allow" : "Deny"
    worker_count                                  = local.config.site_config.worker_count

    dynamic "auto_heal_setting" {
      for_each = local.config.site_config.auto_heal_setting[*]

      content {
        action {
          action_type                    = auto_heal_setting.value.action.action_type
          minimum_process_execution_time = try(auto_heal_setting.value.action.minimum_process_execution_time, null)
        }

        trigger {
          dynamic "requests" {
            for_each = try(auto_heal_setting.value.trigger.requests[*], {})

            content {
              count    = requests.value.count
              interval = requests.value.interval
            }
          }

          dynamic "slow_request" {
            for_each = [ for i in try(auto_heal_setting.value.trigger.slow_requests, []) : i if try(i.path, null) == null ]

            content {
              count      = slow_request.value.count
              interval   = slow_request.value.interval
              time_taken = slow_request.value.time_taken
            }
          }

          dynamic "slow_request_with_path" {
            for_each = [ for i in try(auto_heal_setting.value.trigger.slow_requests, []) : i if try(i.path, null) != null ]

            content {
              count      = slow_request.value.count
              interval   = slow_request.value.interval
              time_taken = slow_request.value.time_taken
              path       = slow_request.value.path
            }
          }

          dynamic "status_code" {
            for_each = try(auto_heal_setting.value.trigger.status_codes, [])

            content {
              count             = status_code.value.count
              interval          = status_code.value.interval
              status_code_range = status_code.value.status_code_range
              path              = try(status_code.value.path, null)
              sub_status        = try(status_code.value.sub_status, null)
              win32_status_code = try(status_code.value.win32_status_code, null)
            }
          }
        }
      }
    }

    dynamic "application_stack" {
      for_each = [ for i in local.config.site_config.application_stack[*] : i if can(coalesce(i.docker_image_name, i.dotnet_version, i.go_version, i.java_version, i.node_version, i.php_version, i.python_version, i.ruby_version)) ]

      content {
        docker_image_name        = application_stack.value.docker_image_name
        docker_registry_url      = application_stack.value.docker_registry_url
        docker_registry_username = application_stack.value.docker_registry_username
        docker_registry_password = application_stack.value.docker_registry_password
        dotnet_version           = application_stack.value.dotnet_version
        go_version               = application_stack.value.go_version
        java_server              = try(application_stack.value.java_server, application_stack.value.java_version != null ? "JAVA" : null)
        java_server_version      = try(application_stack.value.java_server_version, application_stack.value.java_version, null)
        java_version             = application_stack.value.java_version
        node_version             = application_stack.value.node_version
        php_version              = application_stack.value.php_version
        python_version           = application_stack.value.python_version
        ruby_version             = application_stack.value.ruby_version
      }
    }

    dynamic "cors" {
      for_each = local.config.site_config.cors[*]

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = local.config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        headers                   = ip_restriction.value.headers
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        ip_address                = ip_restriction.value.ip_address
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = { for k, v in local.config.scm_ip_restrictions : k => v if !local.config.site_config.scm_use_main_ip_restriction }

      content {
        action                    = scm_ip_restriction.value.action
        headers                   = scm_ip_restriction.value.headers
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        ip_address                = scm_ip_restriction.value.ip_address
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
      }
    }
  }

  app_settings = local.app_settings

  dynamic "sticky_settings" {
    for_each = [ for i in local.config.sticky_settings[*] : i if length(coalesce(i.app_setting_names, i.connection_string_names, keys(local.appinsights_app_settings), local.service_connection_sticky_settings)) > 0 ]

    content {
      app_setting_names       = concat(coalesce(sticky_settings.value.app_setting_names, []), keys(local.appinsights_app_settings), local.service_connection_sticky_settings)
      connection_string_names = sticky_settings.value.connection_string_names
    }
  }

  lifecycle {
    ignore_changes = [
      logs,
      app_settings["AZURE_REDIS_HOST"],
      app_settings["AZURE_REDIS_PORT"],
      app_settings["AZURE_REDIS_DATABASE"],
      app_settings["AZURE_REDIS_SSL"],
      app_settings["AZURE_REDIS_PRINCIPALID"],
      app_settings["AZURE_REDIS_SCOPE"],
      app_settings["AZURE_KEYVAULT_RESOURCEENDPOINT"],
      app_settings["AZURE_KEYVAULT_CLIENTID"],
      app_settings["AZURE_KEYVAULT_SCOPE"],
      app_settings["AZURE_STORAGEBLOB_RESOURCEENDPOINT"],
      app_settings["AZURE_STORAGEBLOB_CLIENTID"],
      app_settings["AZURE_STORAGEBLOB_SCOPE"],
      # Temporary fix to avoid recurring changes to tags until fixed in the azurerm provider.
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/16569
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }
}

resource "azurerm_linux_web_app_slot" "this" {
  for_each = { for k, v in local.config.deployment_slots : k => v if length(azurerm_linux_web_app.this) != 0 }

  name                                           = each.key
  app_service_id                                 = azurerm_linux_web_app.this.0.id
  service_plan_id                                = try(each.value.service_plan_id, null)
  virtual_network_subnet_id                      = try(each.value.virtual_network_subnet_id, local.config.virtual_network_subnet_id)
  https_only                                     = local.config.https_only
  client_certificate_enabled                     = local.config.client_certificate_mode != null
  client_certificate_mode                        = local.config.client_certificate_mode
  client_certificate_exclusion_paths             = local.config.client_certificate_exclusion_paths
  public_network_access_enabled                  = local.config.public_network_access_enabled
  ftp_publish_basic_authentication_enabled       = local.config.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = local.config.webdeploy_publish_basic_authentication_enabled
  zip_deploy_file                                = local.config.zip_deploy_file
  tags                                           = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  site_config {
    always_on                                     = local.config.site_config.always_on
    ftps_state                                    = local.config.site_config.ftps_state
    health_check_path                             = local.config.site_config.health_check_path
    health_check_eviction_time_in_min             = local.config.site_config.health_check_path != null ? local.config.site_config.health_check_eviction_time_in_min : null
    container_registry_managed_identity_client_id = try(coalesce(local.config.site_config.container_registry_managed_identity_client_id, azurerm_user_assigned_identity.this.0.client_id), null)
    container_registry_use_managed_identity       = local.config.site_config.container_registry_use_managed_identity
    minimum_tls_version                           = local.config.site_config.minimum_tls_version
    scm_minimum_tls_version                       = local.config.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction                   = local.config.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                             = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                        = local.config.site_config.vnet_route_all_enabled
    ip_restriction_default_action                 = length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny"
    scm_ip_restriction_default_action             = local.config.site_config.scm_use_main_ip_restriction ? length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny" : length(local.config.scm_ip_restrictions) == 0 ? "Allow" : "Deny"
    worker_count                                  = try(each.value.site_config.worker_count, local.config.site_config.worker_count)
    auto_swap_slot_name                           = try(each.value.site_config.auto_swap_slot_name, null)

    dynamic "auto_heal_setting" {
      for_each = local.config.site_config.auto_heal_setting[*]

      content {
        action {
          action_type                    = auto_heal_setting.value.action.action_type
          minimum_process_execution_time = try(auto_heal_setting.value.action.minimum_process_execution_time, null)
        }

        trigger {
          dynamic "requests" {
            for_each = try(auto_heal_setting.value.trigger.requests[*], {})

            content {
              count    = requests.value.count
              interval = requests.value.interval
            }
          }

          dynamic "slow_request" {
            for_each = [ for i in try(auto_heal_setting.value.trigger.slow_requests, []) : i if try(i.path, null) == null ]

            content {
              count      = slow_request.value.count
              interval   = slow_request.value.interval
              time_taken = slow_request.value.time_taken
            }
          }

          dynamic "slow_request_with_path" {
            for_each = [ for i in try(auto_heal_setting.value.trigger.slow_requests, []) : i if try(i.path, null) != null ]

            content {
              count      = slow_request.value.count
              interval   = slow_request.value.interval
              time_taken = slow_request.value.time_taken
              path       = slow_request.value.path
            }
          }

          dynamic "status_code" {
            for_each = try(auto_heal_setting.value.trigger.status_codes, [])

            content {
              count             = status_code.value.count
              interval          = status_code.value.interval
              status_code_range = status_code.value.status_code_range
              path              = try(status_code.value.path, null)
              sub_status        = try(status_code.value.sub_status, null)
              win32_status_code = try(status_code.value.win32_status_code, null)
            }
          }
        }
      }
    }

    dynamic "application_stack" {
      for_each = [ for i in local.config.site_config.application_stack[*] : i if can(coalesce(i.docker_image_name, i.dotnet_version, i.go_version, i.java_version, i.node_version, i.php_version, i.python_version, i.ruby_version)) ]

      content {
        docker_image_name        = application_stack.value.docker_image_name
        docker_registry_url      = application_stack.value.docker_registry_url
        docker_registry_username = application_stack.value.docker_registry_username
        docker_registry_password = application_stack.value.docker_registry_password
        dotnet_version           = application_stack.value.dotnet_version
        go_version               = application_stack.value.go_version
        java_server              = try(application_stack.value.java_server, application_stack.value.java_version != null ? "JAVA" : null)
        java_server_version      = try(application_stack.value.java_server_version, application_stack.value.java_version, null)
        java_version             = application_stack.value.java_version
        node_version             = application_stack.value.node_version
        php_version              = application_stack.value.php_version
        python_version           = application_stack.value.python_version
        ruby_version             = application_stack.value.ruby_version
      }
    }

    dynamic "cors" {
      for_each = local.config.site_config.cors[*]

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = local.config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        headers                   = ip_restriction.value.headers
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        ip_address                = ip_restriction.value.ip_address
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = { for k, v in local.config.scm_ip_restrictions : k => v if !local.config.site_config.scm_use_main_ip_restriction }

      content {
        action                    = scm_ip_restriction.value.action
        headers                   = scm_ip_restriction.value.headers
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        ip_address                = scm_ip_restriction.value.ip_address
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
      }
    }
  }

  app_settings = merge(
    local.app_settings,
    try(each.value.app_settings, {})
  )

  lifecycle {
    ignore_changes = [
      logs,
      app_settings["AZURE_REDIS_HOST"],
      app_settings["AZURE_REDIS_PORT"],
      app_settings["AZURE_REDIS_DATABASE"],
      app_settings["AZURE_REDIS_SSL"],
      app_settings["AZURE_REDIS_PRINCIPALID"],
      app_settings["AZURE_REDIS_SCOPE"],
      app_settings["AZURE_KEYVAULT_RESOURCEENDPOINT"],
      app_settings["AZURE_KEYVAULT_CLIENTID"],
      app_settings["AZURE_KEYVAULT_SCOPE"],
      app_settings["AZURE_STORAGEBLOB_RESOURCEENDPOINT"],
      app_settings["AZURE_STORAGEBLOB_CLIENTID"],
      app_settings["AZURE_STORAGEBLOB_SCOPE"],
      # Temporary fix to avoid recurring changes to tags until fixed in the azurerm provider.
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/16569
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }
}

resource "azurerm_windows_web_app" "this" {
  count = local.config.os_type == "Windows" && local.config.type == "WebApp" ? 1 : 0

  name                                           = azurecaf_name.app_service.0.result
  resource_group_name                            = local.config.resource_group_name
  location                                       = local.config.location
  service_plan_id                                = local.config.service_plan_id != null ? local.config.service_plan_id : azurerm_service_plan.this.0.id
  virtual_network_subnet_id                      = local.config.virtual_network_subnet_id
  https_only                                     = local.config.https_only
  client_certificate_enabled                     = local.config.client_certificate_mode != null
  client_certificate_mode                        = local.config.client_certificate_mode
  client_certificate_exclusion_paths             = local.config.client_certificate_exclusion_paths
  public_network_access_enabled                  = local.config.public_network_access_enabled
  ftp_publish_basic_authentication_enabled       = local.config.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = local.config.webdeploy_publish_basic_authentication_enabled
  zip_deploy_file                                = local.config.zip_deploy_file
  tags                                           = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  site_config {
    always_on                                     = local.config.site_config.always_on
    ftps_state                                    = local.config.site_config.ftps_state
    health_check_path                             = local.config.site_config.health_check_path
    health_check_eviction_time_in_min             = local.config.site_config.health_check_path != null ? local.config.site_config.health_check_eviction_time_in_min : null
    container_registry_managed_identity_client_id = try(coalesce(local.config.site_config.container_registry_managed_identity_client_id, azurerm_user_assigned_identity.this.0.client_id), null)
    container_registry_use_managed_identity       = local.config.site_config.container_registry_use_managed_identity
    minimum_tls_version                           = local.config.site_config.minimum_tls_version
    scm_minimum_tls_version                       = local.config.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction                   = local.config.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                             = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                        = local.config.site_config.vnet_route_all_enabled
    ip_restriction_default_action                 = length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny"
    scm_ip_restriction_default_action             = local.config.site_config.scm_use_main_ip_restriction ? length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny" : length(local.config.scm_ip_restrictions) == 0 ? "Allow" : "Deny"
    worker_count                                  = local.config.site_config.worker_count

    dynamic "auto_heal_setting" {
      for_each = local.config.site_config.auto_heal_setting[*]

      content {
        action {
          action_type                    = auto_heal_setting.value.action.action_type
          minimum_process_execution_time = try(auto_heal_setting.value.action.minimum_process_execution_time, null)

          dynamic "custom_action" {
            for_each = try(auto_heal_setting.value.custom_action, {})

            content {
              executable = custom_action.value.executable
              parameters = custom_action.value.parameters
            }
          }
        }

        trigger {
          private_memory_kb = try(auto_heal_setting.value.trigger.private_memory_kb, null)

          dynamic "requests" {
            for_each = try(auto_heal_setting.value.trigger.requests[*], {})

            content {
              count    = requests.value.count
              interval = requests.value.interval
            }
          }

          dynamic "slow_request" {
            for_each = [ for i in try(auto_heal_setting.value.trigger.slow_requests, []) : i if try(i.path, null) == null ]

            content {
              count      = slow_request.value.count
              interval   = slow_request.value.interval
              time_taken = slow_request.value.time_taken
            }
          }

          dynamic "slow_request_with_path" {
            for_each = [ for i in try(auto_heal_setting.value.trigger.slow_requests, []) : i if try(i.path, null) != null ]

            content {
              count      = slow_request.value.count
              interval   = slow_request.value.interval
              time_taken = slow_request.value.time_taken
              path       = slow_request.value.path
            }
          }

          dynamic "status_code" {
            for_each = try(auto_heal_setting.value.trigger.status_codes, [])

            content {
              count             = status_code.value.count
              interval          = status_code.value.interval
              status_code_range = status_code.value.status_code_range
              path              = try(status_code.value.path, null)
              sub_status        = try(status_code.value.sub_status, null)
              win32_status_code = try(status_code.value.win32_status_code, null)
            }
          }
        }
      }
    }

    dynamic "application_stack" {
      for_each = [ for i in local.config.site_config.application_stack[*] : i if can(coalesce(i.docker_image_name, i.dotnet_version, i.java_version, i.node_version, i.php_version, i.python_version)) ]

      content {
        docker_image_name            = application_stack.value.docker_image_name
        docker_registry_url          = application_stack.value.docker_registry_url
        docker_registry_username     = application_stack.value.docker_registry_username
        docker_registry_password     = application_stack.value.docker_registry_password
        dotnet_version               = application_stack.value.dotnet_version
        java_embedded_server_enabled = try(application_stack.value.java_embedded_server_enabled, application_stack.value.java_version != null ? true : null)
        java_version                 = application_stack.value.java_version
        node_version                 = application_stack.value.node_version
        php_version                  = application_stack.value.php_version
        python                       = application_stack.value.python
      }
    }

    dynamic "cors" {
      for_each = local.config.site_config.cors[*]

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = local.config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        headers                   = ip_restriction.value.headers
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        ip_address                = ip_restriction.value.ip_address
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = { for k, v in local.config.scm_ip_restrictions : k => v if !local.config.site_config.scm_use_main_ip_restriction }

      content {
        action                    = scm_ip_restriction.value.action
        headers                   = scm_ip_restriction.value.headers
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        ip_address                = scm_ip_restriction.value.ip_address
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
      }
    }
  }

  app_settings = local.app_settings

  dynamic "sticky_settings" {
    for_each = [ for i in local.config.sticky_settings[*] : i if length(coalesce(i.app_setting_names, i.connection_string_names, keys(local.appinsights_app_settings), local.service_connection_sticky_settings)) > 0 ]

    content {
      app_setting_names       = concat(coalesce(sticky_settings.value.app_setting_names, []), keys(local.appinsights_app_settings), local.service_connection_sticky_settings)
      connection_string_names = sticky_settings.value.connection_string_names
    }
  }

  lifecycle {
    ignore_changes = [
      logs,
      app_settings["AZURE_REDIS_HOST"],
      app_settings["AZURE_REDIS_PORT"],
      app_settings["AZURE_REDIS_DATABASE"],
      app_settings["AZURE_REDIS_SSL"],
      app_settings["AZURE_REDIS_PRINCIPALID"],
      app_settings["AZURE_REDIS_SCOPE"],
      app_settings["AZURE_KEYVAULT_RESOURCEENDPOINT"],
      app_settings["AZURE_KEYVAULT_CLIENTID"],
      app_settings["AZURE_KEYVAULT_SCOPE"],
      app_settings["AZURE_STORAGEBLOB_RESOURCEENDPOINT"],
      app_settings["AZURE_STORAGEBLOB_CLIENTID"],
      app_settings["AZURE_STORAGEBLOB_SCOPE"],
      # Temporary fix to avoid recurring changes to tags until fixed in the azurerm provider.
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/16569
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }
}

resource "azurerm_windows_web_app_slot" "this" {
  for_each = { for k, v in local.config.deployment_slots : k => v if length(azurerm_windows_web_app.this) != 0 }

  name                                           = each.key
  app_service_id                                 = azurerm_windows_web_app.this.0.id
  service_plan_id                                = try(each.value.service_plan_id, null)
  virtual_network_subnet_id                      = try(each.value.virtual_network_subnet_id, local.config.virtual_network_subnet_id)
  https_only                                     = local.config.https_only
  client_certificate_enabled                     = local.config.client_certificate_mode != null
  client_certificate_mode                        = local.config.client_certificate_mode
  client_certificate_exclusion_paths             = local.config.client_certificate_exclusion_paths
  public_network_access_enabled                  = local.config.public_network_access_enabled
  ftp_publish_basic_authentication_enabled       = local.config.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = local.config.webdeploy_publish_basic_authentication_enabled
  zip_deploy_file                                = local.config.zip_deploy_file
  tags                                           = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  site_config {
    always_on                                     = local.config.site_config.always_on
    ftps_state                                    = local.config.site_config.ftps_state
    health_check_path                             = local.config.site_config.health_check_path
    health_check_eviction_time_in_min             = local.config.site_config.health_check_path != null ? local.config.site_config.health_check_eviction_time_in_min : null
    container_registry_managed_identity_client_id = try(coalesce(local.config.site_config.container_registry_managed_identity_client_id, azurerm_user_assigned_identity.this.0.client_id), null)
    container_registry_use_managed_identity       = local.config.site_config.container_registry_use_managed_identity
    minimum_tls_version                           = local.config.site_config.minimum_tls_version
    scm_minimum_tls_version                       = local.config.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction                   = local.config.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                             = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                        = local.config.site_config.vnet_route_all_enabled
    ip_restriction_default_action                 = length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny"
    scm_ip_restriction_default_action             = local.config.site_config.scm_use_main_ip_restriction ? length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny" : length(local.config.scm_ip_restrictions) == 0 ? "Allow" : "Deny"
    worker_count                                  = try(each.value.site_config.worker_count, local.config.site_config.worker_count)
    auto_swap_slot_name                           = try(each.value.site_config.auto_swap_slot_name, null)

    dynamic "auto_heal_setting" {
      for_each = local.config.site_config.auto_heal_setting[*]

      content {
        action {
          action_type                    = auto_heal_setting.value.action.action_type
          minimum_process_execution_time = try(auto_heal_setting.value.action.minimum_process_execution_time, null)

          dynamic "custom_action" {
            for_each = try(auto_heal_setting.value.custom_action, {})

            content {
              executable = custom_action.value.executable
              parameters = custom_action.value.parameters
            }
          }
        }

        trigger {
          private_memory_kb = try(auto_heal_setting.value.trigger.private_memory_kb, null)

          dynamic "requests" {
            for_each = try(auto_heal_setting.value.trigger.requests[*], {})

            content {
              count    = requests.value.count
              interval = requests.value.interval
            }
          }

          dynamic "slow_request" {
            for_each = [ for i in try(auto_heal_setting.value.trigger.slow_requests, []) : i if try(i.path, null) == null ]

            content {
              count      = slow_request.value.count
              interval   = slow_request.value.interval
              time_taken = slow_request.value.time_taken
            }
          }

          dynamic "slow_request_with_path" {
            for_each = [ for i in try(auto_heal_setting.value.trigger.slow_requests, []) : i if try(i.path, null) != null ]

            content {
              count      = slow_request.value.count
              interval   = slow_request.value.interval
              time_taken = slow_request.value.time_taken
              path       = slow_request.value.path
            }
          }

          dynamic "status_code" {
            for_each = try(auto_heal_setting.value.trigger.status_codes, [])

            content {
              count             = status_code.value.count
              interval          = status_code.value.interval
              status_code_range = status_code.value.status_code_range
              path              = try(status_code.value.path, null)
              sub_status        = try(status_code.value.sub_status, null)
              win32_status_code = try(status_code.value.win32_status_code, null)
            }
          }
        }
      }
    }

    dynamic "application_stack" {
      for_each = [ for i in local.config.site_config.application_stack[*] : i if can(coalesce(i.docker_image_name, i.dotnet_version, i.java_version, i.node_version, i.php_version, i.python_version)) ]

      content {
        docker_image_name            = application_stack.value.docker_image_name
        docker_registry_url          = application_stack.value.docker_registry_url
        docker_registry_username     = application_stack.value.docker_registry_username
        docker_registry_password     = application_stack.value.docker_registry_password
        dotnet_version               = application_stack.value.dotnet_version
        java_embedded_server_enabled = try(application_stack.value.java_embedded_server_enabled, application_stack.value.java_version != null ? true : null)
        java_version                 = application_stack.value.java_version
        node_version                 = application_stack.value.node_version
        php_version                  = application_stack.value.php_version
        python                       = application_stack.value.python
      }
    }

    dynamic "cors" {
      for_each = local.config.site_config.cors[*]

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = local.config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        headers                   = ip_restriction.value.headers
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        ip_address                = ip_restriction.value.ip_address
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = { for k, v in local.config.scm_ip_restrictions : k => v if !local.config.site_config.scm_use_main_ip_restriction }

      content {
        action                    = scm_ip_restriction.value.action
        headers                   = scm_ip_restriction.value.headers
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        ip_address                = scm_ip_restriction.value.ip_address
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
      }
    }
  }

  app_settings = merge(
    local.app_settings,
    try(each.value.app_settings, {})
  )

  lifecycle {
    ignore_changes = [
      logs,
      app_settings["AZURE_REDIS_HOST"],
      app_settings["AZURE_REDIS_PORT"],
      app_settings["AZURE_REDIS_DATABASE"],
      app_settings["AZURE_REDIS_SSL"],
      app_settings["AZURE_REDIS_PRINCIPALID"],
      app_settings["AZURE_REDIS_SCOPE"],
      app_settings["AZURE_KEYVAULT_RESOURCEENDPOINT"],
      app_settings["AZURE_KEYVAULT_CLIENTID"],
      app_settings["AZURE_KEYVAULT_SCOPE"],
      app_settings["AZURE_STORAGEBLOB_RESOURCEENDPOINT"],
      app_settings["AZURE_STORAGEBLOB_CLIENTID"],
      app_settings["AZURE_STORAGEBLOB_SCOPE"],
      # Temporary fix to avoid recurring changes to tags until fixed in the azurerm provider.
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/16569
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }
}

data "azurerm_client_config" "this" {
}

resource "azurerm_app_service_connection" "this" {
  for_each = merge(
    {
      for k, v in local.config.service_connections : k => merge(
        {
          name           = k
          app_service_id = try(azurerm_linux_web_app.this.0, azurerm_windows_web_app.this.0).id
        },
        v
      ) if local.config.type == "WebApp"
    }
  )

  name               = each.value.name
  app_service_id     = each.value.app_service_id
  target_resource_id = each.value.target_resource_id
  client_type        = each.value.client_type
  vnet_solution      = each.value.vnet_solution

  authentication {
    type            = each.value.authentication.type
    client_id       = each.value.authentication.client_id
    subscription_id = each.value.authentication.client_id != null ? coalesce(each.value.authentication.subscription_id, data.azurerm_client_config.this.subscription_id) : null
  }
}

resource "azurerm_linux_function_app" "this" {
  count = local.config.os_type == "Linux" && local.config.type == "FunctionApp" ? 1 : 0

  name                                           = azurecaf_name.app_service.0.result
  resource_group_name                            = local.config.resource_group_name
  location                                       = local.config.location
  service_plan_id                                = local.config.service_plan_id != null ? local.config.service_plan_id : azurerm_service_plan.this.0.id
  storage_account_name                           = local.config.storage_account_name
  storage_account_access_key                     = local.config.storage_account_access_key
  functions_extension_version                    = local.config.functions_extension_version
  virtual_network_subnet_id                      = local.config.virtual_network_subnet_id
  https_only                                     = local.config.https_only
  builtin_logging_enabled                        = local.config.builtin_logging_enabled
  client_certificate_enabled                     = local.config.client_certificate_mode != null
  client_certificate_mode                        = local.config.client_certificate_mode
  client_certificate_exclusion_paths             = local.config.client_certificate_exclusion_paths
  public_network_access_enabled                  = local.config.public_network_access_enabled
  ftp_publish_basic_authentication_enabled       = local.config.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = local.config.webdeploy_publish_basic_authentication_enabled
  zip_deploy_file                                = local.config.zip_deploy_file
  tags                                           = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  site_config {
    always_on                                     = local.config.site_config.always_on
    ftps_state                                    = local.config.site_config.ftps_state
    health_check_path                             = local.config.site_config.health_check_path
    health_check_eviction_time_in_min             = local.config.site_config.health_check_path != null ? local.config.site_config.health_check_eviction_time_in_min : null
    container_registry_managed_identity_client_id = try(coalesce(local.config.site_config.container_registry_managed_identity_client_id, azurerm_user_assigned_identity.this.0.client_id), null)
    container_registry_use_managed_identity       = local.config.site_config.container_registry_use_managed_identity
    minimum_tls_version                           = local.config.site_config.minimum_tls_version
    scm_minimum_tls_version                       = local.config.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction                   = local.config.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                             = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                        = local.config.site_config.vnet_route_all_enabled
    ip_restriction_default_action                 = length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny"
    scm_ip_restriction_default_action             = local.config.site_config.scm_use_main_ip_restriction ? length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny" : length(local.config.scm_ip_restrictions) == 0 ? "Allow" : "Deny"
    application_insights_connection_string        = local.appinsights_connection_string
    worker_count                                  = local.config.site_config.worker_count

    dynamic "application_stack" {
      for_each = [ for i in local.config.site_config.application_stack[*] : i if can(coalesce(try(i.docker.0.image_name, null), i.dotnet_version, i.java_version, i.node_version, i.python_version, i.powershell_core_version)) ]

      content {
        dynamic "docker" {
          for_each = application_stack.value.docker

          content {
            registry_url      = docker.value.registry_url
            image_name        = docker.value.image_name
            image_tag         = docker.value.image_tag
            registry_username = try(docker.value.registry_username, null)
            registry_password = try(docker.value.registry_password, null)
          }
        }

        dotnet_version              = application_stack.value.dotnet_version
        java_version                = application_stack.value.java_version
        node_version                = application_stack.value.node_version
        python_version              = application_stack.value.python_version
        powershell_core_version     = application_stack.value.powershell_core_version
      }
    }

    dynamic "cors" {
      for_each = local.config.site_config.cors[*]

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = local.config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        headers                   = ip_restriction.value.headers
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        ip_address                = ip_restriction.value.ip_address
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = { for k, v in local.config.scm_ip_restrictions : k => v if !local.config.site_config.scm_use_main_ip_restriction }

      content {
        action                    = scm_ip_restriction.value.action
        headers                   = scm_ip_restriction.value.headers
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        ip_address                = scm_ip_restriction.value.ip_address
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
      }
    }
  }

  app_settings = local.app_settings

  dynamic "sticky_settings" {
    for_each = [ for i in local.config.sticky_settings[*] : i if length(coalesce(i.app_setting_names, i.connection_string_names, keys(local.appinsights_app_settings), local.service_connection_sticky_settings)) > 0 ]

    content {
      app_setting_names       = concat(coalesce(sticky_settings.value.app_setting_names, []), keys(local.appinsights_app_settings), local.service_connection_sticky_settings)
      connection_string_names = sticky_settings.value.connection_string_names
    }
  }

  lifecycle {
    ignore_changes = [
      app_settings["AZURE_REDIS_HOST"],
      app_settings["AZURE_REDIS_PORT"],
      app_settings["AZURE_REDIS_DATABASE"],
      app_settings["AZURE_REDIS_SSL"],
      app_settings["AZURE_REDIS_PRINCIPALID"],
      app_settings["AZURE_REDIS_SCOPE"],
      app_settings["AZURE_KEYVAULT_RESOURCEENDPOINT"],
      app_settings["AZURE_KEYVAULT_CLIENTID"],
      app_settings["AZURE_KEYVAULT_SCOPE"],
      app_settings["AZURE_STORAGEBLOB_RESOURCEENDPOINT"],
      app_settings["AZURE_STORAGEBLOB_CLIENTID"],
      app_settings["AZURE_STORAGEBLOB_SCOPE"],
      site_config.0.application_insights_key,
      # Temporary fix to avoid recurring changes to tags until fixed in the azurerm provider.
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/16569
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }
}

resource "azurerm_linux_function_app_slot" "this" {
  for_each = { for k, v in local.config.deployment_slots : k => v if length(azurerm_linux_function_app.this) != 0 }

  name                                           = each.key
  function_app_id                                = azurerm_linux_function_app.this.0.id
  service_plan_id                                = try(each.value.service_plan_id, null)
  virtual_network_subnet_id                      = try(each.value.virtual_network_subnet_id, local.config.virtual_network_subnet_id)
  storage_account_name                           = local.config.storage_account_name
  storage_account_access_key                     = local.config.storage_account_access_key
  functions_extension_version                    = local.config.functions_extension_version
  https_only                                     = local.config.https_only
  builtin_logging_enabled                        = local.config.builtin_logging_enabled
  client_certificate_enabled                     = local.config.client_certificate_mode != null
  client_certificate_mode                        = local.config.client_certificate_mode
  client_certificate_exclusion_paths             = local.config.client_certificate_exclusion_paths
  public_network_access_enabled                  = local.config.public_network_access_enabled
  ftp_publish_basic_authentication_enabled       = local.config.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = local.config.webdeploy_publish_basic_authentication_enabled
  tags                                           = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  site_config {
    always_on                                     = local.config.site_config.always_on
    ftps_state                                    = local.config.site_config.ftps_state
    health_check_path                             = local.config.site_config.health_check_path
    health_check_eviction_time_in_min             = local.config.site_config.health_check_path != null ? local.config.site_config.health_check_eviction_time_in_min : null
    container_registry_managed_identity_client_id = try(coalesce(local.config.site_config.container_registry_managed_identity_client_id, azurerm_user_assigned_identity.this.0.client_id), null)
    container_registry_use_managed_identity       = local.config.site_config.container_registry_use_managed_identity
    minimum_tls_version                           = local.config.site_config.minimum_tls_version
    scm_minimum_tls_version                       = local.config.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction                   = local.config.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                             = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                        = local.config.site_config.vnet_route_all_enabled
    ip_restriction_default_action                 = length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny"
    scm_ip_restriction_default_action             = local.config.site_config.scm_use_main_ip_restriction ? length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny" : length(local.config.scm_ip_restrictions) == 0 ? "Allow" : "Deny"
    application_insights_connection_string        = local.appinsights_connection_string
    worker_count                                  = try(each.value.site_config.worker_count, local.config.site_config.worker_count)
    auto_swap_slot_name                           = try(each.value.site_config.auto_swap_slot_name, null)

    dynamic "application_stack" {
      for_each = [ for i in local.config.site_config.application_stack[*] : i if can(coalesce(try(i.docker.0.image_name, null), i.dotnet_version, i.java_version, i.node_version, i.python_version, i.powershell_core_version)) ]

      content {
        dynamic "docker" {
          for_each = application_stack.value.docker

          content {
            registry_url      = docker.value.registry_url
            image_name        = docker.value.image_name
            image_tag         = docker.value.image_tag
            registry_username = try(docker.value.registry_username, null)
            registry_password = try(docker.value.registry_password, null)
          }
        }

        dotnet_version              = application_stack.value.dotnet_version
        java_version                = application_stack.value.java_version
        node_version                = application_stack.value.node_version
        python_version              = application_stack.value.python_version
        powershell_core_version     = application_stack.value.powershell_core_version
      }
    }

    dynamic "cors" {
      for_each = local.config.site_config.cors[*]

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = local.config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        headers                   = ip_restriction.value.headers
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        ip_address                = ip_restriction.value.ip_address
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = { for k, v in local.config.scm_ip_restrictions : k => v if !local.config.site_config.scm_use_main_ip_restriction }

      content {
        action                    = scm_ip_restriction.value.action
        headers                   = scm_ip_restriction.value.headers
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        ip_address                = scm_ip_restriction.value.ip_address
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
      }
    }
  }

  app_settings = merge(
    local.app_settings,
    try(each.value.app_settings, {})
  )

  lifecycle {
    ignore_changes = [
      app_settings["AZURE_REDIS_HOST"],
      app_settings["AZURE_REDIS_PORT"],
      app_settings["AZURE_REDIS_DATABASE"],
      app_settings["AZURE_REDIS_SSL"],
      app_settings["AZURE_REDIS_PRINCIPALID"],
      app_settings["AZURE_REDIS_SCOPE"],
      app_settings["AZURE_KEYVAULT_RESOURCEENDPOINT"],
      app_settings["AZURE_KEYVAULT_CLIENTID"],
      app_settings["AZURE_KEYVAULT_SCOPE"],
      app_settings["AZURE_STORAGEBLOB_RESOURCEENDPOINT"],
      app_settings["AZURE_STORAGEBLOB_CLIENTID"],
      app_settings["AZURE_STORAGEBLOB_SCOPE"],
      site_config.0.application_insights_key,
      # Temporary fix to avoid recurring changes to tags until fixed in the azurerm provider.
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/16569
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }
}

resource "azurerm_windows_function_app" "this" {
  count = local.config.os_type == "Windows" && local.config.type == "FunctionApp" ? 1 : 0

  name                                           = azurecaf_name.app_service.0.result
  resource_group_name                            = local.config.resource_group_name
  location                                       = local.config.location
  service_plan_id                                = local.config.service_plan_id != null ? local.config.service_plan_id : azurerm_service_plan.this.0.id
  storage_account_name                           = local.config.storage_account_name
  storage_account_access_key                     = local.config.storage_account_access_key
  functions_extension_version                    = local.config.functions_extension_version
  virtual_network_subnet_id                      = local.config.virtual_network_subnet_id
  builtin_logging_enabled                        = local.config.builtin_logging_enabled
  https_only                                     = local.config.https_only
  client_certificate_enabled                     = local.config.client_certificate_mode != null
  client_certificate_mode                        = local.config.client_certificate_mode
  client_certificate_exclusion_paths             = local.config.client_certificate_exclusion_paths
  public_network_access_enabled                  = local.config.public_network_access_enabled
  ftp_publish_basic_authentication_enabled       = local.config.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = local.config.webdeploy_publish_basic_authentication_enabled
  zip_deploy_file                                = local.config.zip_deploy_file
  tags                                           = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  site_config {
    always_on                              = local.config.site_config.always_on
    ftps_state                             = local.config.site_config.ftps_state
    health_check_path                      = local.config.site_config.health_check_path
    health_check_eviction_time_in_min      = local.config.site_config.health_check_path != null ? local.config.site_config.health_check_eviction_time_in_min : null
    minimum_tls_version                    = local.config.site_config.minimum_tls_version
    scm_minimum_tls_version                = local.config.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction            = local.config.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                      = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                 = local.config.site_config.vnet_route_all_enabled
    ip_restriction_default_action          = length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny"
    scm_ip_restriction_default_action      = local.config.site_config.scm_use_main_ip_restriction ? length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny" : length(local.config.scm_ip_restrictions) == 0 ? "Allow" : "Deny"
    application_insights_connection_string = local.appinsights_connection_string
    worker_count                           = local.config.site_config.worker_count

    dynamic "application_stack" {
      for_each = [ for i in local.config.site_config.application_stack[*] : i if can(coalesce(i.dotnet_version, i.java_version, i.node_version, i.powershell_core_version)) ]

      content {
        dotnet_version              = application_stack.value.dotnet_version
        use_dotnet_isolated_runtime = application_stack.value.use_dotnet_isolated_runtime
        java_version                = application_stack.value.java_version
        node_version                = application_stack.value.node_version
        powershell_core_version     = application_stack.value.powershell_core_version
      }
    }

    dynamic "cors" {
      for_each = local.config.site_config.cors[*]

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = local.config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        headers                   = ip_restriction.value.headers
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        ip_address                = ip_restriction.value.ip_address
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = { for k, v in local.config.scm_ip_restrictions : k => v if !local.config.site_config.scm_use_main_ip_restriction }

      content {
        action                    = scm_ip_restriction.value.action
        headers                   = scm_ip_restriction.value.headers
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        ip_address                = scm_ip_restriction.value.ip_address
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
      }
    }
  }

  app_settings = local.app_settings

  dynamic "sticky_settings" {
    for_each = [ for i in local.config.sticky_settings[*] : i if length(coalesce(i.app_setting_names, i.connection_string_names, keys(local.appinsights_app_settings), local.service_connection_sticky_settings)) > 0 ]

    content {
      app_setting_names       = concat(coalesce(sticky_settings.value.app_setting_names, []), keys(local.appinsights_app_settings), local.service_connection_sticky_settings)
      connection_string_names = sticky_settings.value.connection_string_names
    }
  }

  lifecycle {
    ignore_changes = [
      app_settings["AZURE_REDIS_HOST"],
      app_settings["AZURE_REDIS_PORT"],
      app_settings["AZURE_REDIS_DATABASE"],
      app_settings["AZURE_REDIS_SSL"],
      app_settings["AZURE_REDIS_PRINCIPALID"],
      app_settings["AZURE_REDIS_SCOPE"],
      app_settings["AZURE_KEYVAULT_RESOURCEENDPOINT"],
      app_settings["AZURE_KEYVAULT_CLIENTID"],
      app_settings["AZURE_KEYVAULT_SCOPE"],
      app_settings["AZURE_STORAGEBLOB_RESOURCEENDPOINT"],
      app_settings["AZURE_STORAGEBLOB_CLIENTID"],
      app_settings["AZURE_STORAGEBLOB_SCOPE"],
      site_config.0.application_insights_key,
      # Temporary fix to avoid recurring changes to tags until fixed in the azurerm provider.
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/16569
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }
}

resource "azurerm_windows_function_app_slot" "this" {
  for_each = { for k, v in local.config.deployment_slots : k => v if length(azurerm_windows_function_app.this) != 0 }

  name                                           = each.key
  function_app_id                                = azurerm_windows_function_app.this.0.id
  service_plan_id                                = try(each.value.service_plan_id, null)
  virtual_network_subnet_id                      = try(each.value.virtual_network_subnet_id, local.config.virtual_network_subnet_id)
  storage_account_name                           = local.config.storage_account_name
  storage_account_access_key                     = local.config.storage_account_access_key
  functions_extension_version                    = local.config.functions_extension_version
  https_only                                     = local.config.https_only
  builtin_logging_enabled                        = local.config.builtin_logging_enabled
  client_certificate_enabled                     = local.config.client_certificate_mode != null
  client_certificate_mode                        = local.config.client_certificate_mode
  client_certificate_exclusion_paths             = local.config.client_certificate_exclusion_paths
  public_network_access_enabled                  = local.config.public_network_access_enabled
  ftp_publish_basic_authentication_enabled       = local.config.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = local.config.webdeploy_publish_basic_authentication_enabled
  tags                                           = local.config.tags

  dynamic "identity" {
    for_each = local.config.identity.type[*]

    content {
      type         = local.config.identity.type
      identity_ids = local.config.identity.type == "SystemAssigned" ? null : concat(azurerm_user_assigned_identity.this[*].id, local.config.identity.identity_ids)
    }
  }

  site_config {
    always_on                              = local.config.site_config.always_on
    ftps_state                             = local.config.site_config.ftps_state
    health_check_path                      = local.config.site_config.health_check_path
    health_check_eviction_time_in_min      = local.config.site_config.health_check_path != null ? local.config.site_config.health_check_eviction_time_in_min : null
    minimum_tls_version                    = local.config.site_config.minimum_tls_version
    scm_minimum_tls_version                = local.config.site_config.scm_minimum_tls_version
    scm_use_main_ip_restriction            = local.config.site_config.scm_use_main_ip_restriction
    use_32_bit_worker                      = local.config.site_config.use_32_bit_worker
    vnet_route_all_enabled                 = local.config.site_config.vnet_route_all_enabled
    ip_restriction_default_action          = length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny"
    scm_ip_restriction_default_action      = local.config.site_config.scm_use_main_ip_restriction ? length(local.config.ip_restrictions) == 0 ? "Allow" : "Deny" : length(local.config.scm_ip_restrictions) == 0 ? "Allow" : "Deny"
    application_insights_connection_string = local.appinsights_connection_string
    worker_count                           = try(each.value.site_config.worker_count, local.config.site_config.worker_count)
    auto_swap_slot_name                    = try(each.value.site_config.auto_swap_slot_name, null)

    dynamic "application_stack" {
      for_each = [ for i in local.config.site_config.application_stack[*] : i if can(coalesce(i.dotnet_version, i.java_version, i.node_version, i.powershell_core_version)) ]

      content {
        dotnet_version              = application_stack.value.dotnet_version
        use_dotnet_isolated_runtime = application_stack.value.use_dotnet_isolated_runtime
        java_version                = application_stack.value.java_version
        node_version                = application_stack.value.node_version
        powershell_core_version     = application_stack.value.powershell_core_version
      }
    }

    dynamic "cors" {
      for_each = local.config.site_config.cors[*]

      content {
        allowed_origins     = cors.value.allowed_origins
        support_credentials = cors.value.support_credentials
      }
    }

    dynamic "ip_restriction" {
      for_each = local.config.ip_restrictions

      content {
        action                    = ip_restriction.value.action
        headers                   = ip_restriction.value.headers
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        ip_address                = ip_restriction.value.ip_address
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = { for k, v in local.config.scm_ip_restrictions : k => v if !local.config.site_config.scm_use_main_ip_restriction }

      content {
        action                    = scm_ip_restriction.value.action
        headers                   = scm_ip_restriction.value.headers
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        ip_address                = scm_ip_restriction.value.ip_address
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id
      }
    }
  }

  app_settings = merge(
    local.app_settings,
    try(each.value.app_settings, {})
  )

  lifecycle {
    ignore_changes = [
      app_settings["AZURE_REDIS_HOST"],
      app_settings["AZURE_REDIS_PORT"],
      app_settings["AZURE_REDIS_DATABASE"],
      app_settings["AZURE_REDIS_SSL"],
      app_settings["AZURE_REDIS_PRINCIPALID"],
      app_settings["AZURE_REDIS_SCOPE"],
      app_settings["AZURE_KEYVAULT_RESOURCEENDPOINT"],
      app_settings["AZURE_KEYVAULT_CLIENTID"],
      app_settings["AZURE_KEYVAULT_SCOPE"],
      app_settings["AZURE_STORAGEBLOB_RESOURCEENDPOINT"],
      app_settings["AZURE_STORAGEBLOB_CLIENTID"],
      app_settings["AZURE_STORAGEBLOB_SCOPE"],
      site_config.0.application_insights_key,
      # Temporary fix to avoid recurring changes to tags until fixed in the azurerm provider.
      # See: https://github.com/hashicorp/terraform-provider-azurerm/issues/16569
      tags["hidden-link: /app-insights-conn-string"],
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
    ]
  }
}

resource "azurerm_function_app_connection" "this" {
  for_each = merge(
    {
      for k, v in local.config.service_connections : k => merge(
        {
          name            = k
          function_app_id = try(azurerm_linux_function_app.this.0, azurerm_windows_function_app.this.0).id
        },
        v
      ) if local.config.type == "FunctionApp"
    }
  )

  name               = each.value.name
  function_app_id    = each.value.function_app_id
  target_resource_id = each.value.target_resource_id
  client_type        = each.value.client_type
  vnet_solution      = each.value.vnet_solution

  authentication {
    type            = each.value.authentication.type
    client_id       = each.value.authentication.client_id
    subscription_id = each.value.authentication.client_id != null ? coalesce(each.value.authentication.subscription_id, data.azurerm_client_config.this.subscription_id) : null
  }
}
