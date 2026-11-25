# dev was built by hand on Nov 24; these blocks take it over.
# Resources inside a module have addresses that start with "module.<name>.".
# The RG, identity and groups are NOT here: onboarding owns them.

locals {
  sub     = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  rg      = "${local.sub}/resourceGroups/rg-dev-cc"
  hub_rg  = "${local.sub}/resourceGroups/rg-hub-cc"
  vnet    = "${local.rg}/providers/Microsoft.Network/virtualNetworks/vnet-spoke-dev-cc"
  subnets = ["aks", "app", "endpoints", "ops"]
  nsgs    = ["app", "endpoints", "ops"]
  zones   = ["privatelink.blob.core.windows.net", "privatelink.vaultcore.azure.net"]
}

import {
  to = module.env.azurerm_virtual_network.spoke
  id = local.vnet
}

import {
  for_each = toset(local.subnets)
  to       = module.env.azurerm_subnet.this[each.key]
  id       = "${local.vnet}/subnets/snet-${each.key}"
}

import {
  for_each = toset(local.nsgs)
  to       = module.env.azurerm_network_security_group.this[each.key]
  id       = "${local.rg}/providers/Microsoft.Network/networkSecurityGroups/nsg-${each.key}-dev-cc"
}

# An NSG association has no ID of its own: Terraform uses the subnet's ID.
import {
  for_each = toset(local.nsgs)
  to       = module.env.azurerm_subnet_network_security_group_association.this[each.key]
  id       = "${local.vnet}/subnets/snet-${each.key}"
}

import {
  to = module.env.azurerm_virtual_network_peering.spoke_to_hub
  id = "${local.vnet}/virtualNetworkPeerings/peer-dev-to-hub"
}

import {
  to = module.env.azurerm_virtual_network_peering.hub_to_spoke
  id = "${local.hub_rg}/providers/Microsoft.Network/virtualNetworks/vnet-hub-cc/virtualNetworkPeerings/peer-hub-to-dev"
}

import {
  for_each = toset(local.zones)
  to       = module.env.azurerm_private_dns_zone_virtual_network_link.spoke[each.key]
  id       = "${local.hub_rg}/providers/Microsoft.Network/privateDnsZones/${each.key}/virtualNetworkLinks/link-vnet-spoke-dev-cc"
}

import {
  to = module.env.azurerm_key_vault.this
  id = "${local.rg}/providers/Microsoft.KeyVault/vaults/kv-platform-dev-cc"
}

import {
  to = module.env.azurerm_private_endpoint.kv
  id = "${local.rg}/providers/Microsoft.Network/privateEndpoints/pe-kv-platform-dev-cc"
}
