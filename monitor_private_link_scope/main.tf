resource "azurerm_monitor_private_link_scoped_service" "this" {
  count = var.linked_resource_id != null && var.private_link_scope_id != null ? 1 : 0

  linked_resource_id  = var.linked_resource_id
  name                = provider::azurerm::parse_resource_id(var.linked_resource_id).resource_name
  resource_group_name = provider::azurerm::parse_resource_id(var.private_link_scope_id).resource_group_name
  scope_name          = provider::azurerm::parse_resource_id(var.private_link_scope_id).resource_name
}
