terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Same state storage, but NOT dev.tfstate: own file = own lifecycle (destroy AKS, keep the network).
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-cc"
    storage_account_name = "sttfstate0"
    container_name       = "tfstate"
    key                  = "dev-workloads.tfstate"
    use_azuread_auth     = true
  }
}
