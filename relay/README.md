# Terraform module for deploying Azure Relay resources

Use this module to deploy Azure Relay resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```hcl
module "relay" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/relay"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group
}
```

## Resources

[Terraform Azure Relay Namespace reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/relay_namespace)

[Terraform Azure Relay Namespace Authorization Rule reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/relay_namespace_authorization_rule)

[Terraform Azure Relay Hybrid Connection reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/relay_hybrid_connection)

[Terraform Azure Hybrid Connection Authorization Rule reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/relay_hybrid_connection_authorization_rule)
