# dev's workloads: compute that can be destroyed and rebuilt without touching
# envs/dev (network, Key Vault). stage and prod get copies with their own values.

module "workloads" {
  source = "../../../modules/workloads"

  env = "dev"

  # Quota: 4 vCPUs in canadacentral for everything. Keep 2 free for the ops VM later.
  node_vm_size = "Standard_D2s_v7"
  node_count   = 1
}
