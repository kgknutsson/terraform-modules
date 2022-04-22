output "subnet_ids" {
  value       = { for k, v in azurerm_subnet.this : k => v.id }
  description = "Map containing ids of subnets within the virtual network."
}
