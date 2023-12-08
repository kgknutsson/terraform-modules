output "hybrid_connection_key_id_map" {
  description = ""
  value       = { for k, v in azurerm_relay_hybrid_connection.this : k => v.id }
}
