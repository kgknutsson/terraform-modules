terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.77.0, < 5.0"
    }

    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = ">= 1.2.21"
    }
  }
}
