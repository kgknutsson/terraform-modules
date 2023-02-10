output "id" {
  value       = try(azurerm_key_vault.this.0.id, null)
  description = "Key vault id."
}
