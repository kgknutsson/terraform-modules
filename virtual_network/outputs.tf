output "id" {
  value       = try(azurerm_virtual_network.this.0.id, null)
  description = "Id of the virtual network."
}

output "subnet" {
  value       = try(azurerm_virtual_network.this.0.subnet, toset([]))
  description = "List of subnets within the virtual network."
}

output "subnet_id_map" {
  value       = { for k, v in azurerm_subnet.this : k => v.id }
  description = "Map of subnet ids within the virtual network."
}
