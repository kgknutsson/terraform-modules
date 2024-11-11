output "id" {
  value       = try(azurerm_storage_account.this.0.id, null)
  description = "Storage account id."
}

output "name" {
  value       = try(azurerm_storage_account.this.0.name, null)
  description = "Storage account name."
}

output "primary_access_key" {
  value       = try(azurerm_storage_account.this.0.primary_access_key, null)
  description = "Storage Account primary access key."
}

output "primary_connection_string" {
  value       = try(azurerm_storage_account.this.0.primary_connection_string, null)
  description = "Storage Account primary connection string."
}

output "primary_blob_endpoint" {
  value       = try(azurerm_storage_account.this.0.primary_blob_endpoint, null)
  description = "Storage Account primary blob endpoint."
}
