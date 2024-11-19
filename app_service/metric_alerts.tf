resource "azurerm_monitor_diagnostic_setting" "this" {
  count = min(
    length(local.config.type[*]),
    length(local.config.os_type[*]),
    length(local.config.insights.workspace_id[*]),
    try(length(local.config.monitor_diagnostic_setting.enabled_logs) + length(local.config.monitor_diagnostic_setting.metrics), 1)
  )

  name                       = "SendToLogAnalytics"
  target_resource_id         = try(azurerm_windows_web_app.this.0, azurerm_linux_web_app.this.0, azurerm_windows_function_app.this.0, azurerm_linux_function_app.this.0, azapi_resource.flex_function.0).id
  log_analytics_workspace_id = local.config.insights.workspace_id

  dynamic "enabled_log" {
    for_each = local.config.monitor_diagnostic_setting.enabled_logs

    content {
      category       = try(enabled_log.value.category, null)
      category_group = try(enabled_log.value.category_group, null)
    }
  }

  dynamic "metric" {
    for_each = local.config.monitor_diagnostic_setting.metrics

    content {
      category = try(metric.value.category, metric.value)
      enabled  = try(metric.value.enabled, true)
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
  count = local.config.metric_alerts.enabled && try(length(regexall("^(?:Y|FC|EP)[0-9]+$", local.config.sku_name)) == 0, false) ? 1 : 0

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
  count = local.config.metric_alerts.enabled && try(length(regexall("^(?:Y|FC|EP)[0-9]+$", local.config.sku_name)) == 0, false) ? 1 : 0

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
  count = min(length(azurerm_application_insights.this), local.config.metric_alerts.enabled && local.config.type == "WebApp" ? 1 : 0)

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
