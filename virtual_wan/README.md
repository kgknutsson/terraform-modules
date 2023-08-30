# Terraform module for deploying Azure Virtual WAN resources

Use this module to deploy Azure Virtual WAN resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "virtual_wan" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/virtual_wan"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group
}
```

## Resources

[Terraform Azure Virtual WAN reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_wan)

[Terraform Azure Virtual Hub reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_hub)

[Terraform Azure VPN Gateway reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_gateway)

[Terraform Azure VPN Site reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_site)

[Terraform Azure VPN Gateway Connection reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/vpn_gateway_connection)
