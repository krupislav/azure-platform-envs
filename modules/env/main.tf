# ENV module: the blueprint of one environment (a spoke). Called once per
# environment from envs/<name>. Runs as the environment's pipeline identity.
#
# Already there before this runs (NOT created here):
#   - the resource group, identity and access groups -> onboarding layer (admin)
#   - the hub VNet and the private DNS zones          -> global layer
# This module only fills the resource group and connects it to the hub.

locals {
  rg_name  = "rg-${var.env}-cc"
  vnet     = "vnet-spoke-${var.env}-cc"
  kv_name  = "kv-platform-${var.env}-cc"
  tags     = { env = var.env }
  hub_rg   = "rg-hub-cc"
  hub_vnet = "vnet-hub-cc"

  # Subnets that get their own NSG (snet-aks doesn't: AKS brings its own).
  nsg_subnets = { for k, s in var.subnets : k => s if s.nsg }

  dns_zones = [
    "privatelink.blob.core.windows.net",
    "privatelink.vaultcore.azure.net",
  ]
}

data "azurerm_client_config" "current" {}

# ---------- Read what other layers own ----------

data "azurerm_resource_group" "env" {
  name = local.rg_name
}

data "azurerm_virtual_network" "hub" {
  name                = local.hub_vnet
  resource_group_name = local.hub_rg
}

data "azurerm_private_dns_zone" "this" {
  for_each = toset(local.dns_zones)

  name                = each.key
  resource_group_name = local.hub_rg
}

# ---------- Spoke network ----------

resource "azurerm_virtual_network" "spoke" {
  name                = local.vnet
  resource_group_name = data.azurerm_resource_group.env.name
  location            = var.location
  address_space       = [var.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                            = "snet-${each.key}"
  resource_group_name             = data.azurerm_resource_group.env.name
  virtual_network_name            = azurerm_virtual_network.spoke.name
  address_prefixes                = [each.value.prefix]
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "this" {
  for_each = local.nsg_subnets

  name                = "nsg-${each.key}-${var.env}-cc"
  resource_group_name = data.azurerm_resource_group.env.name
  location            = var.location
  tags                = local.tags
  # No rules yet: the built-in defaults allow VNet-to-VNet and deny internet in.
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsg_subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# ---------- Peering: both directions, or it doesn't connect ----------

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${var.env}-to-hub"
  resource_group_name       = data.azurerm_resource_group.env.name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

# Lives in the HUB's resource group, but belongs to this environment.
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-${var.env}"
  resource_group_name       = data.azurerm_virtual_network.hub.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = true
}

# Link the spoke to each shared zone, so names like kv-...vault.azure.net
# resolve to the private IP inside the spoke.
resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = data.azurerm_private_dns_zone.this

  name                  = "link-${local.vnet}"
  resource_group_name   = local.hub_rg
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = local.tags
}

# ---------- Key Vault: two gates ----------
# RBAC says WHO (roles on the RG, from onboarding); the private endpoint says FROM WHERE.

resource "azurerm_key_vault" "this" {
  name                = local.kv_name
  resource_group_name = data.azurerm_resource_group.env.name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  soft_delete_retention_days    = 90
  purge_protection_enabled      = false # dev: lets you purge and reuse the name. Prod: true.

  network_acls {
    bypass         = "None"
    default_action = "Deny"
  }

  tags = local.tags
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-${local.kv_name}"
  resource_group_name = data.azurerm_resource_group.env.name
  location            = var.location
  subnet_id           = azurerm_subnet.this["endpoints"].id
  tags                = local.tags

  private_service_connection {
    name                           = coalesce(var.kv_pe_connection_name, "psc-${local.kv_name}")
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  # Azure creates and deletes the A record together with the endpoint.
  # (Yesterday's record was made as a plain record: this takes it over.)
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.this["privatelink.vaultcore.azure.net"].id]
  }
}
