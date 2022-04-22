data "azurerm_monitor_diagnostic_categories" "this" {
  count = try(length(local.config.diagnostic_categories.logs), 1) + try(length(local.config.diagnostic_categories.metrics), 1) > 0 ? length(local.config.insights.workspace_id[*]) : 0

  resource_id = try(azurerm_app_service.this.0, azurerm_function_app.this.0).id
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = length(data.azurerm_monitor_diagnostic_categories.this)

  name                       = "SendToLogAnalytics"
  target_resource_id         = try(azurerm_app_service.this.0, azurerm_function_app.this.0).id
  log_analytics_workspace_id = local.config.insights.workspace_id

  dynamic "log" {
    for_each = coalesce(local.config.diagnostic_categories.logs, data.azurerm_monitor_diagnostic_categories.this.0.logs)

    content {
      category = log.value

      retention_policy {
        days    = 0
        enabled = false
      }
    }
  }

  dynamic "metric" {
    for_each = coalesce(local.config.diagnostic_categories.metrics, data.azurerm_monitor_diagnostic_categories.this.0.metrics)

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
  count = local.config.metric_alerts ? 1 : 0

  name                     = "CPU usage above threshold - ${azurerm_app_service_plan.this.name}"
  resource_group_name      = var.resource_group
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [azurerm_app_service_plan.this.id]
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
}

resource "azurerm_monitor_metric_alert" "mem90" {
  count = local.config.metric_alerts ? 1 : 0

  name                     = "Memory usage above threshold - ${azurerm_app_service_plan.this.name}"
  resource_group_name      = var.resource_group
  target_resource_location = local.config.location
  tags                     = local.config.tags
  scopes                   = [azurerm_app_service_plan.this.id]
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
}

resource "azurerm_monitor_metric_alert" "heap80" {
  count = min(length(local.config.insights.workspace_id[*]), local.config.metric_alerts && local.config.type == "WebApp" ? 1 : 0)

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
}
