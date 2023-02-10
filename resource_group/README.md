# Terraform module for deploying Azure Resource Group resources

Use this module to deploy Azure Resource Group resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "resource_group" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/resource_group"

  config         = local.config
  environment    = var.environment
}
```

## Resources

[Terraform Azure Resource Group reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group)
