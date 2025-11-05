output "id" {
  value = try(azurerm_api_management.this[0].id, data.azurerm_api_management.this[0].id, null)
  description = "Id of the API Management instance."
}

output "location" {
  value       = try(azurerm_api_management.this[0].location, data.azurerm_api_management.this[0].location, null)
  description = "Location of the API Management instance."
}

output "public_ip_addresses" {
  value       = try(azurerm_api_management.this[0].public_ip_addresses, data.azurerm_api_management.this[0].public_ip_addresses, null)
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
