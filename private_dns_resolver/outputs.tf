output "id" {
  value       = try(azurerm_private_dns_resolver.this[0].id, null)
  description = "Private DNS resolver id."
}
