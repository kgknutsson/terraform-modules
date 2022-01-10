output "subnet_ids" {
  value       = { for k, v in azurerm_subnet.this : k => v.id }
}
