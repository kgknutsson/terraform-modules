# Terraform module for deploying Azure Storage Account resources

Use this module to deploy Azure Storage Account resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "storage_account" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/storage_account"

  config          = local.config
  environment     = var.environment
  resource_group  = module.resource_group

  // Optional
  virtual_network = module.virtual_network
}
```

## Resources

[Terraform Azure Storage Account reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account)
