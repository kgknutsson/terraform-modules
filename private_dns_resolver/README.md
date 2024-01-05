# Terraform module for deploying Azure Private DNS Resolver resources

Use this module to deploy Azure Private DNS Resolver resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "private_dns_resolver" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/private_dns_resolver"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group

  // Optional
  virtual_network = module.virtual_network
}
```

## Resources

[Terraform Azure Private DNS Resolver reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_resolver)

[Terraform Azure Private DNS Resolver Inbound Endpoint reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_resolver_inbound_endpoint)

[Terraform Azure Private DNS Resolver Outbound Endpoint reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_resolver_outbound_endpoint)

[Terraform Azure Private DNS Resolver DNS Forwarding Ruleset reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_resolver_dns_forwarding_ruleset)

[Terraform Azure Private DNS Resolver Forwarding Rule reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_resolver_forwarding_rule)

[Terraform Azure Private DNS Resolver Virtual Network Link reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_resolver_virtual_network_link)
