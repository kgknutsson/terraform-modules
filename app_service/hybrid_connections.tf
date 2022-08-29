resource "azurecaf_name" "relay_namespace" {
  count = length(keys(local.config.hybrid_connections)[*])

  name          = local.config.name
  resource_type = "azurerm_relay_namespace"
  suffixes      = [var.environment]
}

resource "azurerm_relay_namespace" "this" {
  count = length(azurecaf_name.relay_namespace)

  name                = azurecaf_name.relay_namespace.0.result
  resource_group_name = var.resource_group
  location            = local.config.location
  tags                = local.config.tags
  sku_name            = "Standard"
}

resource "azurerm_relay_hybrid_connection" "this" {
  for_each = local.config.hybrid_connections

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

resource "azurerm_relay_hybrid_connection_authorization_rule" "listen" {
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
  listen                 = true // Needed because web_app_hybrid_connection have no separate listen_key_name property.
  send                   = true
}

resource "azurerm_web_app_hybrid_connection" "this" {
  for_each = { for k, v in azurerm_relay_hybrid_connection.this : k => v if local.config.type == "WebApp" }

  web_app_id    = try(azurerm_windows_web_app.this.0, azurerm_linux_web_app.this.0, azurerm_windows_function_app.this.0, azurerm_linux_function_app.this.0).id
  relay_id      = each.value.id
  hostname      = local.config.hybrid_connections[each.key].hostname
  port          = local.config.hybrid_connections[each.key].port
  send_key_name = azurerm_relay_hybrid_connection_authorization_rule.send[each.key].name
}

resource "azurerm_function_app_hybrid_connection" "this" {
  for_each = { for k, v in azurerm_relay_hybrid_connection.this : k => v if local.config.type == "FunctionApp" }

  function_app_id = try(azurerm_windows_web_app.this.0, azurerm_linux_web_app.this.0, azurerm_windows_function_app.this.0, azurerm_linux_function_app.this.0).id
  relay_id        = each.value.id
  hostname        = local.config.hybrid_connections[each.key].hostname
  port            = local.config.hybrid_connections[each.key].port
  send_key_name   = azurerm_relay_hybrid_connection_authorization_rule.send[each.key].name
}
