output "virtual_machine_caf_name" {
  value       = try(azurecaf_name.linux_virtual_machine_scale_set.0.result, null)
  description = "The virtual machine name generated by Azure Cloud Adoption Framework."
}

output "system_assigned_identity_principal_id" {
  value       = try(azurerm_linux_virtual_machine_scale_set.this[0].identity[0].principal_id, null)
  description = "System assigned identity principal id."
}
