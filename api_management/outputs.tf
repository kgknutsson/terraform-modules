output "public_ip_addresses" {
  value       = azurerm_api_management.this.public_ip_addresses
  description = "Public IP addresses"
}
