output "id" {
  value       = try(azurerm_key_vault.this.0.id, null)
  description = "Key vault id."
}

output "monitor_config" {
  value = {
    diagnostic_settings = try(
      [
        {
          name               = "SendToLogAnalytics"
          target_resource_id = azurerm_key_vault.this.0.id
          log_category_types = null
          metrics            = null
        }
      ],
      []
    )
  }
}
