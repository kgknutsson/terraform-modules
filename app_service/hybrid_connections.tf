resource "azurecaf_name" "relay_namespace" {
  count = length(keys(var.hybrid_connections)[*])

  name          = var.settings.name
  resource_type = "azurerm_relay_namespace"
  suffixes      = [var.settings.environment]
}

resource "azurerm_relay_namespace" "this" {
  count = length(azurecaf_name.relay_namespace)

  name                = azurecaf_name.relay_namespace.0.result
  location            = azurerm_app_service_plan.this.location
  resource_group_name = azurerm_app_service_plan.this.resource_group_name
  sku_name            = "Standard"
  tags                = var.settings.tags
}

resource "azurerm_relay_hybrid_connection" "this" {
  for_each = var.hybrid_connections

  name                 = each.key
  relay_namespace_name = azurerm_relay_namespace.this.0.name
  resource_group_name  = azurerm_relay_namespace.this.0.resource_group_name

  user_metadata = jsonencode(
    [
      {
        key   = "endpoint"
        value = "${each.value.hostname}:${each.value.port}"
      }
    ]
  )
}

resource "azurerm_relay_hybrid_connection_authorization_rule" "list" {
  for_each = azurerm_relay_hybrid_connection.this

  name                   = "defaultListener"
  resource_group_name    = each.value.resource_group_name
  hybrid_connection_name = each.value.name
  namespace_name         = each.value.relay_namespace_name
  listen                 = true
}

resource "azurerm_relay_hybrid_connection_authorization_rule" "send" {
  for_each = azurerm_relay_hybrid_connection.this

  name                   = "defaultSender"
  resource_group_name    = each.value.resource_group_name
  hybrid_connection_name = each.value.name
  namespace_name         = each.value.relay_namespace_name
  send                   = true
}

resource "azurerm_app_service_hybrid_connection" "this" {
  for_each = azurerm_relay_hybrid_connection.this

  app_service_name    = (var.is_function ? azurerm_function_app.this.0.name : azurerm_app_service.this.0.name)
  resource_group_name = each.value.resource_group_name
  relay_id            = each.value.id
  hostname            = var.hybrid_connections[each.key].hostname
  port                = var.hybrid_connections[each.key].port
  send_key_name       = azurerm_relay_hybrid_connection_authorization_rule.send[each.key].name
}
