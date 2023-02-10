# Terraform module for deploying Azure Virtual Network resources

Use this module to deploy Azure Virtual Network resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "virtual_network" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/virtual_network"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group
}
```

## Resources

[Terraform Azure Virtual Network reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)

[Terraform Azure Subnet reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet)

[Terraform Azure Private Endpoint reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint)

[Terraform Azure Private DNS Zone reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone)

[Terraform Azure Private DNS Zone Virtual Network Link reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link)
