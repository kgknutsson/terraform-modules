output "id" {
  value       = try(azurerm_private_dns_resolver.this[0].id, null)
  description = "Private DNS resolver id."
}

output "dns_forwarding_ruleset_id" {
  value       = try(azurerm_private_dns_resolver_dns_forwarding_ruleset.this[0].id, null)
  description = "Private DNS resolver forwarding ruleset id"
}
