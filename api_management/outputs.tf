output "public_ip_addresses" {
  value       = try(azurerm_api_management.this[0].public_ip_addresses, null)
  description = "Public IP addresses"
}

output "monitor_config" {
  value = {
    diagnostic_settings = try(
      [
        {
          name               = "SendToLogAnalytics"
          target_resource_id = azurerm_api_management.this[0].id
          log_category_types = null
          metrics            = null
        }
      ],
      []
    )
  }
}
