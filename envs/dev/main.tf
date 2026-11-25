# dev = the env module with dev's values. stage and prod will be copies of
# this folder with their own values (10.21, 10.22) and their own state file.

module "env" {
  source = "../../modules/env"

  env           = "dev"
  address_space = "10.23.0.0/16"

  subnets = {
    aks       = { prefix = "10.23.0.0/22", nsg = false }
    app       = { prefix = "10.23.4.0/24", nsg = true }
    endpoints = { prefix = "10.23.5.0/24", nsg = true }
    ops       = { prefix = "10.23.6.0/24", nsg = true }
  }

  # dev's endpoint was built in the portal (connection name with a GUID).
  kv_pe_connection_name = "pe-kv-platform-dev-cc_62875d24-6348-4ede-9962-dd19f11e614d"
}
