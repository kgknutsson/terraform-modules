output "static_site_default_hostnames" {
  value       = { for k, v in azurerm_static_site.this : k => "https://${v.default_host_name}" }
  description = "The default URL of the Static Web App."
}

output "static_site_api_keys" {
  value       = { for k, v in azurerm_static_site.this : k => v.api_key }
  description = "The API key of this Static Web App."
}
