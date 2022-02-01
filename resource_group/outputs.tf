output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "The resource group name."
}

//TODO: Jag hade även outputat, i vilken subscription ID resursgruppen skapats i, samt region OM ni börjar köra i flera regioner än West Europe för tydlighetsskull. 