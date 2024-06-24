output "primary_access_key" {
  description = ""
  value       = try(azurerm_redis_cache.this[0].primary_access_key, null)
}
