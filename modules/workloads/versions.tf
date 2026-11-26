# A module declares which providers it needs, but never configures them
# (no backend, no provider settings): the caller (envs/<name>) does that.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
