output "public_ip_addresses" {
  value       = try(azurerm_api_management.this[0].public_ip_addresses, null)
  description = "Public IP addresses"
}
