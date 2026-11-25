terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Same state storage as the platform layers, its own file.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-cc"
    storage_account_name = "sttfstate0"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
    use_azuread_auth     = true
  }
}
