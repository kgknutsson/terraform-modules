locals {
  resource_map = {
    mssql_elasticpool = length(local.config.elastic_pools) > 0 ? merge(var.resource_group, { scopes = [ for k, v in azurerm_mssql_elasticpool.this : v.id ] }) : null
    mssql_database    = length(local.config.databases) > 0 ? var.resource_group : null
  }

  activity_log_alerts = flatten([
    for k, v in yamldecode(
      file("${path.module}/activity_log_alerts.yml")
    ) : [
      for i in try(local.config.monitor_activity_log_alerts[k], v) : merge(
        i,
        {
          formatted_name = format("%s (%s)", i.name, local.resource_map[k].name)
          scopes         = try(local.resource_map[k].scopes, [local.resource_map[k].id])
          criteria       = merge({ resource_groups = [ var.resource_group.id ] }, i.criteria)
          action         = [ for id in local.config.monitor_default_action_group_ids : { action_group_id = id } ]
        }
      )
    ] if local.resource_map[k] != null && local.config.monitor_activity_log_alerts_enabled
  ])

  metric_alerts = flatten([
    for k, v in yamldecode(
      file("${path.module}/metric_alerts.yml")
    ) : [
      for i in try(local.config.monitor_metric_alerts[k], v) : merge(
        i,
        {
          formatted_name           = format("%s (%s)", i.name, local.resource_map[k].name)
          scopes                   = try(local.resource_map[k].scopes, [local.resource_map[k].id])
          target_resource_location = try(local.resource_map[k].location, null)
          action                   = [ for id in local.config.monitor_default_action_group_ids : { action_group_id = id } ]
        }
      )
    ] if local.resource_map[k] != null && local.config.monitor_metric_alerts_enabled
  ])
}

output "msi_client_ids" {
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.client_id }
  description = "User assigned identitiy client ids."
}

output "monitor_config" {
  value = {
    activity_log_alerts = local.activity_log_alerts
    metric_alerts       = local.metric_alerts
  }
}
