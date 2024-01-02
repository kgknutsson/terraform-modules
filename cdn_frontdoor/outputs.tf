output "profile_id" {
  description = "CDN Front Door profile id"
  value       = try(azurerm_cdn_frontdoor_profile.this[0].id, null)
}

output "host_names" {
  description = "CDN Front Door host names"
  value       = concat(values(azurerm_cdn_frontdoor_endpoint.this)[*].host_name, values(azurerm_cdn_frontdoor_custom_domain.this)[*].host_name)
}

output "monitor_config" {
  value = {
    diagnostic_settings = try(
      [
        {
          name               = "SendToLogAnalytics"
          target_resource_id = azurerm_cdn_frontdoor_profile.this[0].id
          log_category_types = null
          metrics            = null
        }
      ],
      []
    )
  }
}
