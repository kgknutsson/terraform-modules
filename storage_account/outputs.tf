output "storage_account_name" {
  value       = azurerm_storage_account.this.name
  description = "Storage Account name."
}

output "storage_account_access_key" {
  value       = azurerm_storage_account.this.primary_access_key
  description = "Storage Account access key."
}
