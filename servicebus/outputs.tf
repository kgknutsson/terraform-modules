output "namespace_id" {
  description = ""
  value       = try(azurerm_servicebus_namespace.this[0].id, null)
}

output "queue_id_map" {
  description = ""
  value       = { for k, v in azurerm_servicebus_queue.this : k => v.id }
}
/*
output "topic_id_map" {
  description = ""
  value       = { for k, v in azurerm_servicebus_topic.this : k => v.id }
}
*/
output "monitor_config" {
  value = {
    diagnostic_settings = [
      for i in azurerm_servicebus_namespace.this : {
        name               = "SendToLogAnalytics"
        target_resource_id = i.id
        log_category_types = null
        metrics            = null
      }
    ]
  }
}
