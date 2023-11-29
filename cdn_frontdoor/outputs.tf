output "cdn_frontdoor_profile_id" {
  description = "The CDN Frontdoor Profile Id"
  value       = try(azurerm_cdn_frontdoor_profile.this[0].id, null)
}
