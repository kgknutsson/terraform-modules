locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name                = var.config.global.name
    location            = var.resource_group.location
    resource_group_name = var.resource_group.name

    tags = merge(
      {
        application = var.config.global.name
        environment = var.environment
        terraform   = "true"
      },
      var.tags,
      try(var.config.global.tags, {}),
      try(local.env_config.tags, {}),
      try(var.config.global.monitor.tags, {}),
      try(local.env_config.monitor.tags, {})
    )

    log_analytics_workspace_id = try(local.env_config.monitor.log_analytics_workspace_id, var.config.global.monitor.log_analytics_workspace_id, null)
    default_action_group_ids   = distinct(concat(try(local.env_config.monitor.default_action_group_ids, []), try(var.config.global.monitor.default_action_group_ids, []), try(local.env_config.app_service.metric_alerts.action_group_ids, []), try(var.config.global.app_service.metric_alerts.action_group_ids, [])))

    autoscale_settings = try(
      var.monitor_config.autoscale_setting,
      concat(
        try(var.config.global.monitor.autoscale_settings, []),
        try(local.env_config.monitor.autoscale_settings, [])
      )
    )

    diagnostic_settings = try(
      var.monitor_config.diagnostic_settings,
      concat(
        try(var.config.global.monitor.diagnostic_settings, []),
        try(local.env_config.monitor.diagnostic_settings, [])
      )
    )

    action_groups = merge(
      try(var.config.global.monitor.action_groups, {}),
      try(local.env_config.monitor.action_groups, {})
    )

    activity_log_alerts = try(
      var.monitor_config.activity_log_alerts,
      concat(
        try(var.config.global.monitor.activity_log_alerts, []),
        try(local.env_config.monitor.activity_log_alerts, [])
      )
    )

    metric_alerts = try(
      var.monitor_config.metric_alerts,
      concat(
        try(var.config.global.monitor.metric_alerts, []),
        try(local.env_config.monitor.metric_alerts, [])
      )
    )
  }
}

resource "azurerm_monitor_autoscale_setting" "this" {
  for_each = { for i in local.config.autoscale_settings : i.name => i }

  name                = each.key
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  target_resource_id  = each.value.target_resource_id
  tags                = local.config.tags

  dynamic "profile" {
    for_each = each.value.profiles

    content {
      name = profile.key

      capacity {
        default = profile.value.capacity.default
        minimum = profile.value.capacity.minimum
        maximum = profile.value.capacity.maximum
      }
      dynamic "rule" {
        for_each = []

        content {
          metric_trigger {
            metric_resource_id       = ""
            metric_name              = ""
            metric_namespace         = null
            operator                 = ""
            statistic                = ""
            time_aggregation         = ""
            time_grain               = ""
            time_window              = ""
            threshold                = ""
            divide_by_instance_count = null

            dynamic "dimensions" {
              for_each = []

              content {
                name     = ""
                operator = "" // Equals or NotEquals
                values   = []
              }
            }
          }

          scale_action {
            cooldown  = ""
            direction = "" // Increase or Decrease
            type      = "" // ChangeCount, ExactCount, PercentChangeCount or ServiceAllowedNextValue
            value     = ""
          }
        }
      }
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "this" {
  for_each = { for i in local.config.diagnostic_settings : i.name => i.target_resource_id }

  resource_id = each.value
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = { for i in local.config.diagnostic_settings : i.name => i }

  name                           = each.value.name
  target_resource_id             = each.value.target_resource_id
  log_analytics_workspace_id     = try(each.value.log_analytics_workspace_id, local.config.log_analytics_workspace_id)
  log_analytics_destination_type = try(each.value.log_analytics_destination_type, null) // AzureDiagnostics or Dedicated

  dynamic "enabled_log" {
    for_each = coalesce(each.value.log_category_types, data.azurerm_monitor_diagnostic_categories.this[each.key].log_category_types)

    content {
      category = enabled_log.value
    }
  }

  dynamic "metric" {
    for_each = coalesce(each.value.metrics, data.azurerm_monitor_diagnostic_categories.this[each.key].metrics)

    content {
      category = metric.value
    }
  }
}

resource "azurerm_monitor_action_group" "this" {
  for_each = local.config.action_groups
  
  name                = each.key
  resource_group_name = local.config.resource_group_name
  tags                = local.config.tags
  short_name          = try(each.value.short_name, each.key)
  enabled             = try(each.value.enabled, true)

  dynamic "email_receiver" {
    for_each = try(each.value.email_receiver, [])

    content {
      name          = email_receiver.value.name
      email_address = email_receiver.value.email_address
    }
  }
}

resource "azurerm_monitor_activity_log_alert" "this" {
  for_each = { for i in local.config.activity_log_alerts : i.name => i }

  name                     = coalesce(try(each.value.formatted_name, null), each.key)
  resource_group_name      = local.config.resource_group_name
  tags                     = local.config.tags
  scopes                   = each.value.scopes
  description              = try(each.value.description, null)
  enabled                  = try(each.value.enabled, true)

  criteria {
    category        = each.value.criteria.category // Administrative, Autoscale, Policy, Recommendation, ResourceHealth, Security or ServiceHealth
    resource_groups = try(each.value.criteria.resource_groups, [])
    resource_types  = try(each.value.criteria.resource_types, [])

    dynamic "resource_health" {
      for_each = try(each.value.criteria.resource_health[*], [])
      content {
        current  = try(resource_health.value.current, [])
        previous = try(resource_health.value.previous, [])
        reason   = try(resource_health.value.reason, [])
      }
    }

    dynamic "service_health" {
      for_each = try(each.value.criteria.service_health[*], [])

      content {
        events    = try(service_health.value.events, [])
        locations = try(service_health.value.locations, [])
        services  = try(service_health.value.services, [])
      }
    }
  }

  dynamic "action" {
    for_each = try(each.value.action, [ for id in local.config.default_action_group_ids : { action_group_id = id } ])

    content {
      action_group_id    = try(azurerm_monitor_action_group.this[action.value.action_group_id].id, action.value.action_group_id)
      webhook_properties = try(action.value.webhook_properties, null)
    }
  }
}

resource "azurerm_monitor_metric_alert" "this" {
  for_each = { for i in local.config.metric_alerts : i.name => i }

  name                     = coalesce(try(each.value.formatted_name, null), each.key)
  resource_group_name      = local.config.resource_group_name
  tags                     = local.config.tags
  scopes                   = each.value.scopes
  description              = try(each.value.description, null)
  severity                 = try(each.value.severity, 3) // 0, 1, 2, 3 or 4
  target_resource_type     = try(each.value.target_resource_type, null)
  target_resource_location = try(each.value.target_resource_location, local.config.location)
  frequency                = try(each.value.frequency, "PT1M") // PT1M, PT5M, PT15M, PT30M or PT1H
  window_size              = try(each.value.window_size, "PT5M") // PT1M, PT5M, PT15M, PT30M, PT1H, PT6H, PT12H or P1D
  auto_mitigate            = try(each.value.auto_mitigate, true)
  enabled                  = try(each.value.enabled, true)

  dynamic "criteria" {
    for_each = try(each.value.criteria, [])
    
    content {
      metric_namespace       = criteria.value.metric_namespace
      metric_name            = criteria.value.metric_name
      aggregation            = criteria.value.aggregation // Average, Count, Minimum, Maximum or Total
      operator               = criteria.value.operator // Equals, NotEquals, GreaterThan, GreaterThanOrEqual, LessThan or LessThanOrEqual
      threshold              = criteria.value.threshold
      skip_metric_validation = try(criteria.value.skip_metric_validation, false)

      dynamic "dimension" {
        for_each = try(criteria.value.dimension, [])

        content {
          name     = dimention.value.name
          operator = dimention.value.operator // Include, Exclude or StartsWith
          values   = dimention.value.values
        }
      }
    }
  }

  dynamic "dynamic_criteria" {
    for_each = try(each.value.dynamic_criteria, [])

    content {
      metric_namespace         = dynamic_criteria.value.metric_namespace
      metric_name              = dynamic_criteria.value.metric_name
      aggregation              = dynamic_criteria.value.aggregation // Average, Count, Minimum, Maximum or Total
      operator                 = dynamic_criteria.value.operator // LessThan, GreaterThan or GreaterOrLessThan
      alert_sensitivity        = dynamic_criteria.value.alert_sensitivity // Low, Medium or High
      evaluation_total_count   = try(dynamic_criteria.value.evaluation_total_count, 4)
      evaluation_failure_count = try(dynamic_criteria.value.evaluation_failure_count, 4)
      ignore_data_before       = try(dynamic_criteria.value.ignore_data_before, null)
      skip_metric_validation   = try(dynamic_criteria.value.skip_metric_validation, false)

      dynamic "dimension" {
        for_each = try(dynamic_criteria.value.dimension, [])

        content {
          name     = dimention.value.name
          operator = dimention.value.operator // Include, Exclude or StartsWith
          values   = dimention.value.values
        }
      }
    }
  }

  dynamic "application_insights_web_test_location_availability_criteria" {
    for_each = try(each.value.application_insights_web_test_location_availability_criteria, [])

    content {
      web_test_id           = application_insights_web_test_location_availability_criteria.value.web_test_id
      component_id          = application_insights_web_test_location_availability_criteria.value.component_id
      failed_location_count = application_insights_web_test_location_availability_criteria.value.failed_location_count
    }
  }

  dynamic "action" {
    for_each = try(each.value.action, [ for id in local.config.default_action_group_ids : { action_group_id = id } ])

    content {
      action_group_id    = try(azurerm_monitor_action_group.this[action.value.action_group_id].id, action.value.action_group_id)
      webhook_properties = try(action.value.webhook_properties, null)
    }
  }
}
