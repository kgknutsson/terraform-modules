output "id" {
  value       = try(azurerm_virtual_network.this.0.id, data.azurerm_virtual_network.this.0.id, null)
  description = "Id of the virtual network."
}

output "subnet" {
  value       = try(azurerm_virtual_network.this.0.subnet, data.azurerm_virtual_network.this.0.subnets, toset([]))
  description = "List of subnets within the virtual network."
}

output "subnet_id_map" {
  value       = { for k, v in azurerm_subnet.this : k => v.id }
  description = "Map of subnet ids within the virtual network."
}

output "private_dns_zone_id_map" {
  value       = { for k, v in azurerm_private_dns_zone.this : k => v.id }
  description = "Map of private DNS zone ids within the virtual network."
}
