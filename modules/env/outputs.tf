output "vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "subnet_ids" {
  value = { for k, s in azurerm_subnet.this : k => s.id }
}

output "key_vault_id" {
  value = azurerm_key_vault.this.id
}
