# Terraform module for deploying Azure Cache for Redis resources

Use this module to deploy Azure Cache for Redis resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```hcl
module "redis" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/redis"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group
}
```

## Resources

[Terraform AzureRM Redis Cache reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/redis_cache)

[Terraform AzureRM Redis Cache Access Policy Assignment reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/redis_cache_access_policy_assignment)
