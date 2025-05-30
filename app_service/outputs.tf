locals {
  default_hostname = try(try(azurerm_windows_web_app.this.0, azurerm_linux_web_app.this.0, azurerm_windows_function_app.this.0, azurerm_linux_function_app.this.0).default_hostname, azapi_resource.flex_function[0].output.properties.defaultHostName, null)
}

output "service_plan_id" {
  value       = try(azurerm_service_plan.this.0.id, local.config.service_plan_id)
  description = "Service plan id."
}

output "service_plan_os_type" {
  value       = try(azurerm_service_plan.this.0.os_type, local.config.os_type)
  description = "Service plan OS type."
}

output "application_insights_resource_id" {
  value       = try(azurerm_application_insights.this.0.id, var.app_service.application_insights_resource_id, null)
  description = "Application insights resource id."
}

output "application_insights_connection_string" {
  value       = try(azurerm_application_insights.this.0.connection_string, var.app_service.application_insights_connection_string, null)
  description = "Application insights connection string."
}

output "application_insights_workspace_id" {
  value       = try(azurerm_application_insights.this.0.workspace_id, var.app_service.application_insights_workspace_id, null)
  description = "Application insights connection string."
}

output "application_insights_private_link_scope_id" {
  value       = local.config.insights.private_link_scope_id
  description = "Application insights private link scope."
}

output "system_assigned_identity_principal_id" {
  value = try(try(azurerm_windows_web_app.this[0], azurerm_linux_web_app.this[0], azurerm_windows_function_app.this[0], azurerm_linux_function_app.this[0], azapi_resource.flex_function[0]).identity[0].principal_id, null)
  description = "System assigned identity principal id."
}

output "user_assigned_identity_id" {
  value       = try(azurerm_user_assigned_identity.this.0.id, null)
  description = "User assigned identity id"
}

output "user_assigned_identity_client_id" {
  value       = try(azurerm_user_assigned_identity.this.0.client_id, null)
  description = "User assigned identity client_id"
}

output "virtual_network_subnet_id" {
  value       = local.config.virtual_network_subnet_id
  description = "Virtual network subnet id."
}

output "application_hostname" {
  value       = try("https://${local.default_hostname}", null)
  description = "Application URL."
}

output "application_caf_name" {
  value       = try(azurecaf_name.app_service.0.result, null)
  description = "Application name generated by Azure Cloud Adoption Framework."
}

output "database_jdbc_string" {
  value       = local.database_jdbc_basestring
  description = "Database URL."
}
