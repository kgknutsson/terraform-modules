locals {
  resource_id = try(azurerm_windows_web_app.this.0, azurerm_linux_web_app.this.0, azurerm_windows_function_app.this.0, azurerm_linux_function_app.this.0).id
}

data "azurerm_monitor_diagnostic_categories" "this" {
  resource_id = local.resource_id
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = min(
    length(local.config.insights.workspace_id[*]),
    try(length(local.config.monitor_diagnostic_setting.log_category_types) + length(local.config.monitor_diagnostic_setting.metrics), 1)
  )

  name                       = "SendToLogAnalytics"
  target_resource_id         = local.resource_id
  log_analytics_workspace_id = local.config.insights.workspace_id

  dynamic "log" {
    for_each = coalesce(local.config.monitor_diagnostic_setting.log_category_types, data.azurerm_monitor_diagnostic_categories.this.log_category_types)

    content {
      category = log.value

      retention_policy {
        days    = 0
        enabled = false
      }
    }
  }

  dynamic "metric" {
    for_each = coalesce(local.config.monitor_diagnostic_setting.metrics, data.azurerm_monitor_diagnostic_categories.this.metrics)

    content {
      category = metric.value

      retention_policy {
        days    = 0
        enabled = false
      }
    }
  }
}

resource "azurerm_monitor_metric_alert" "cpu90" {
  count = local.config.metric_alerts.enabled ? 1 : 0

  name                     = "CPU usage above threshold - ${azurerm_service_plan.this.name}"
  resource_group_name      = var.resource_group
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [azurerm_service_plan.this.id]
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
  count = local.config.metric_alerts.enabled ? 1 : 0

  name                     = "Memory usage above threshold - ${azurerm_service_plan.this.name}"
  resource_group_name      = var.resource_group
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [azurerm_service_plan.this.id]
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
  resource_group_name      = var.resource_group
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [azurerm_application_insights.this.0.id]
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
