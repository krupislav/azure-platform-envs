# Subscription comes from $env:ARM_SUBSCRIPTION_ID (not in the public repo).
# Runs as: you (az login) while taking dev over, then the pipeline (id-github-dev).

provider "azurerm" {
  features {}
}

# Used only to build resource IDs in imports.tf.
data "azurerm_client_config" "current" {}
