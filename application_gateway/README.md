# Terraform module for deploying Azure Application Gateway resources

Use this module to deploy Azure Application Gateway resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "application_gateway" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/application_gateway"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group

  // Optional
  virtual_network = module.virtual_network
  key_vault       = module.key_vault
}
```

## Resources

[Terraform Azure Application Gateway reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_gateway)

[Terraform Azure Public IP reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip)

[Terraform Azure User Assigned Identity reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity)
