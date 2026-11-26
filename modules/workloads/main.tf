# WORKLOADS module: the compute of one environment (AKS). Own state file, so it
# can be destroyed every night without touching the network or Key Vault.
#
# Already there before this runs (NOT created here):
#   - rg-<env>-cc, id-aks-<env>, id-aks-kubelet-<env> and all their roles -> onboarding (admin)
#   - vnet-spoke-<env>-cc and snet-aks                                     -> envs/<env> (env module)
# Behind the scenes Azure creates the node resource group MC_rg-<env>-cc_aks-<env>-cc_<region>
# with the node scale set and the load balancer. AKS owns it: never edit it by hand.

locals {
  rg_name      = "rg-${var.env}-cc"
  cluster_name = "aks-${var.env}-cc"
  # The MC_ resource group copies the cluster's tags; the policy denies an RG without env.
  tags = { env = var.env }
}

data "azurerm_client_config" "current" {}

# ---------- Read what other layers own ----------

data "azurerm_resource_group" "env" {
  name = local.rg_name
}

data "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  virtual_network_name = "vnet-spoke-${var.env}-cc"
  resource_group_name  = local.rg_name
}

# Control plane identity (onboarding): Network Contributor on the RG.
data "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-${var.env}"
  resource_group_name = local.rg_name
}

# Kubelet identity (onboarding): AcrPull on acrshared0.
data "azurerm_user_assigned_identity" "kubelet" {
  name                = "id-aks-kubelet-${var.env}"
  resource_group_name = local.rg_name
}

# ---------- The cluster ----------

resource "azurerm_kubernetes_cluster" "this" {
  name                = local.cluster_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.env.name
  dns_prefix          = local.cluster_name
  sku_tier            = "Free" # control plane at no cost; no uptime SLA (prod: Standard)
  tags                = local.tags

  default_node_pool {
    name                        = "system"
    vm_size                     = var.node_vm_size
    node_count                  = var.node_count
    vnet_subnet_id              = data.azurerm_subnet.aks.id
    temporary_name_for_rotation = "systemtmp" # lets Terraform change the VM size without destroying the cluster
    tags                        = local.tags
  }

  # Who the control plane is (pre-created, so its roles already exist).
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.aks.id]
  }

  # Who the nodes are (pulls images). Needs all three values of the kubelet identity.
  kubelet_identity {
    client_id                 = data.azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = data.azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = data.azurerm_user_assigned_identity.kubelet.id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"       # nodes get snet-aks IPs, pods get IPs from pod_cidr
    pod_cidr            = "10.244.0.0/16" # only inside the cluster, never seen in the VNet
    service_cidr        = "10.0.0.0/16"   # Kubernetes Service IPs; must not overlap any VNet (10.20, 10.23)
    dns_service_ip      = "10.0.0.10"
    outbound_type       = "loadBalancer" # internet out via the LB's public IP (subnets have no default outbound)
  }

  # Sign-in with Entra ID; Azure RBAC decides what you can do (sg-aks-<env>-admins).
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }
  local_account_disabled = true

  # For later (Key Vault): pods get their own identity through the cluster's OIDC issuer.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
}
