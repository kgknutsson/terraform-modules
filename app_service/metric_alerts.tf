resource "azurerm_monitor_metric_alert" "cpu90" {
  count = var.skip_alerts ? 0 : 1

  name                     = "CPU usage above threshold - ${azurerm_app_service_plan.this.name}"
  resource_group_name      = azurerm_app_service_plan.this.resource_group_name
  target_resource_location = azurerm_app_service_plan.this.location
  tags                     = var.settings.tags
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
  count = var.skip_alerts ? 0 : 1

  name                     = "Memory usage above threshold - ${azurerm_app_service_plan.this.name}"
  resource_group_name      = azurerm_app_service_plan.this.resource_group_name
  target_resource_location = azurerm_app_service_plan.this.location
  tags                     = var.settings.tags
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
  count = min(length(var.insights_workspace_id[*]), var.skip_alerts || var.is_function ? 0 : 1)

  name                     = "Java heap usage above threshold - ${azurerm_application_insights.this.0.name}"
  resource_group_name      = azurerm_application_insights.this.0.resource_group_name
  target_resource_location = azurerm_application_insights.this.0.location
  tags                     = var.settings.tags
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
