# Inputs: the only things that differ between dev, stage and prod.
# Everything else (names, settings) is derived inside the module, so the
# environments can't drift apart.

variable "env" {
  description = "Environment name: dev, stage, prod. Used in every resource name and the env tag."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "canadacentral"
}

variable "address_space" {
  description = "Spoke VNet range. Must not overlap the hub (10.20/16) or other spokes."
  type        = string
}

# key = short name ("app" -> subnet "snet-app", NSG "nsg-app-<env>-cc")
variable "subnets" {
  description = "Spoke subnets: short name => { prefix, nsg = whether it gets its own NSG }."
  type = map(object({
    prefix = string
    nsg    = bool
  }))
}

# Only for taking over an endpoint built in the portal: the portal names the
# connection "<endpoint>_<guid>", and changing that name replaces the endpoint.
# New environments leave it out and get a clean name.
variable "kv_pe_connection_name" {
  description = "Override for the Key Vault private endpoint's connection name (imports only)."
  type        = string
  default     = null
}
