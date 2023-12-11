data "azurerm_monitor_diagnostic_categories" "this" {
  count = min(
    length(concat(azurerm_windows_web_app.this, azurerm_linux_web_app.this, azurerm_windows_function_app.this, azurerm_linux_function_app.this)),
    length(local.config.insights.workspace_id[*]),
    try(length(local.config.monitor_diagnostic_setting.log_category_types) + length(local.config.monitor_diagnostic_setting.metrics), 1)
  )

  resource_id = try(azurerm_windows_web_app.this.0, azurerm_linux_web_app.this.0, azurerm_windows_function_app.this.0, azurerm_linux_function_app.this.0).id
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = length(data.azurerm_monitor_diagnostic_categories.this)

  name                       = "SendToLogAnalytics"
  target_resource_id         = data.azurerm_monitor_diagnostic_categories.this.0.resource_id
  log_analytics_workspace_id = local.config.insights.workspace_id

  dynamic "enabled_log" {
    for_each = coalesce(local.config.monitor_diagnostic_setting.log_category_types, data.azurerm_monitor_diagnostic_categories.this.0.log_category_types)

    content {
      category = enabled_log.value

      retention_policy {
        days    = 0
        enabled = false
      }
    }
  }

  dynamic "metric" {
    for_each = coalesce(local.config.monitor_diagnostic_setting.metrics, data.azurerm_monitor_diagnostic_categories.this.0.metrics)

    content {
      category = metric.value

      retention_policy {
        days    = 0
        enabled = false
      }
    }
  }
}

resource "azurerm_monitor_metric_alert" "healthcheck" {
  count = local.config.metric_alerts.enabled && local.config.type != null && local.config.site_config.health_check_path != null ? 1 : 0

  name                     = "App is unhealthy - ${try(azurerm_windows_web_app.this.0, azurerm_linux_web_app.this.0, azurerm_windows_function_app.this.0, azurerm_linux_function_app.this.0).name}"
  resource_group_name      = local.config.resource_group_name
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [try(azurerm_windows_web_app.this.0, azurerm_linux_web_app.this.0, azurerm_windows_function_app.this.0, azurerm_linux_function_app.this.0).id]
  description              = "Whenever the average health check status is less than 100%"
  severity                 = 1
  target_resource_type     = "Microsoft.Web/sites"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HealthCheckStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = "100"
  }

  dynamic "action" {
    for_each = local.config.metric_alerts.action_group_ids

    content {
      action_group_id = action.value
    }
  }
}

resource "azurerm_monitor_metric_alert" "cpu90" {
  count = local.config.metric_alerts.enabled && length(azurerm_service_plan.this) > 0 ? 1 : 0

  name                     = "CPU usage above threshold - ${azurerm_service_plan.this.0.name}"
  resource_group_name      = local.config.resource_group_name
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [azurerm_service_plan.this.0.id]
  window_size              = "PT15M"
  description              = "Whenever the average cpu percentage is greater than 90%"
  severity                 = 2
  target_resource_type     = "Microsoft.Web/serverfarms"

  criteria {
    metric_namespace = "microsoft.web/serverfarms"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = "90"
  }

  dynamic "action" {
    for_each = local.config.metric_alerts.action_group_ids

    content {
      action_group_id = action.value
    }
  }
}

resource "azurerm_monitor_metric_alert" "mem90" {
  count = local.config.metric_alerts.enabled && length(azurerm_service_plan.this) > 0 ? 1 : 0

  name                     = "Memory usage above threshold - ${azurerm_service_plan.this.0.name}"
  resource_group_name      = local.config.resource_group_name
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [azurerm_service_plan.this.0.id]
  window_size              = "PT15M"
  description              = "Whenever the avg memory percentage is greater than 90%"
  severity                 = 2
  target_resource_type     = "Microsoft.Web/serverfarms"

  criteria {
    metric_namespace = "microsoft.web/serverfarms"
    metric_name      = "MemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = "90"
  }

  dynamic "action" {
    for_each = local.config.metric_alerts.action_group_ids

    content {
      action_group_id = action.value
    }
  }
}

resource "azurerm_monitor_metric_alert" "heap80" {
  count = min(length(local.config.insights.workspace_id[*]), local.config.metric_alerts.enabled && local.config.type == "WebApp" ? 1 : 0)

  name                     = "Java heap usage above threshold - ${azurerm_application_insights.this.0.name}"
  resource_group_name      = local.config.resource_group_name
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [azurerm_application_insights.this.0.id]
  window_size              = "PT15M"
  description              = "Whenever the avg % of max heap memory used is greater than 80"
  severity                 = 2
  target_resource_type     = "Microsoft.Insights/Components"

  criteria {
    metric_namespace = "azure.applicationinsights"
    metric_name      = "% Of Max Heap Memory Used"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = "80"

    # Needed as sometimes the metric hasn't been reported yet
    skip_metric_validation = true
  }

  dynamic "action" {
    for_each = local.config.metric_alerts.action_group_ids

    content {
      action_group_id = action.value
    }
  }
}

resource "azurerm_monitor_metric_alert" "responsetime" {
  count = min(length(local.config.insights.workspace_id[*]), local.config.metric_alerts.enabled && local.config.type == "WebApp" ? 1 : 0)

  name                     = "Server response time above threshold - ${azurerm_application_insights.this.0.name}"
  resource_group_name      = local.config.resource_group_name
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [azurerm_application_insights.this.0.id]
  window_size              = "PT5M"
  description              = "Whenever server response time is greater than 35 sec."
  severity                 = 2
  target_resource_type     = "Microsoft.Insights/Components"

  criteria {
    metric_namespace = "azure.applicationinsights"
    metric_name      = "requests/duration"
    aggregation      = "Maximum"
    operator         = "GreaterThan"
    threshold        = "35000"

    # Needed as sometimes the metric hasn't been reported yet
    skip_metric_validation = true
  }

  dynamic "action" {
    for_each = local.config.metric_alerts.action_group_ids

    content {
      action_group_id = action.value
    }
  }
}
