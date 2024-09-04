output "default_hostnames" {
  value       = { for k, v in azurerm_static_web_app.this : k => "https://${v.default_host_name}" }
  description = "The default URL of the Static Web App(s)."
}

output "api_keys" {
  value       = { for k, v in azurerm_static_web_app.this : k => v.api_key }
  description = "The API key of the Static Web App(s)."
}

output "identity_principal_ids" {
  value = { for k, v in azurerm_static_web_app.this : k => v.identity.0.principal_id if length(v.identity) > 0 }
}
