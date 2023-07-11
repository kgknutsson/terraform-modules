output "msi_client_ids" {
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.client_id }
  description = "User assigned identitiy client ids."
}
