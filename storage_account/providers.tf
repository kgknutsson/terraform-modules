terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 5.4.0, < 6.0.0"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = ">= 1.2.31, < 2.0.0"
    }
  }
}
