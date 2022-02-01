terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.75"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = ">= 1.2.6"
    }
  }
}

// TODO: Hur authar de sig mot AZ? AZ CLI, Manged Service Identity, Service Princpal + Cert