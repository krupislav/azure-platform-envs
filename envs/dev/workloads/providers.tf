# Subscription comes from ARM_SUBSCRIPTION_ID (pipeline secret / your env var).
# Runs as the dev pipeline (id-github-dev): same identity as envs/dev, own state file.

provider "azurerm" {
  features {}
}
