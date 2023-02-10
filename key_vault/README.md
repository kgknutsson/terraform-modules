# Terraform module for deploying Azure Key Vault resources

Use this module to deploy Azure Key Vault resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "key_vault" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/key_vault"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group

  // Optional
  virtual_network = module.virtual_network
}
```

## Resources

[Terraform Azure Key Vault reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault)
