# Terraform module for deploying Azure CDN Front Door resources

Use this module to deploy Azure CDN Front Door resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```hcl
module "cdn_frontdoor" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/cdn_frontdoor"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group

  // Optional
  key_vault      = module.key_vault
}
```

## Resources

[Terraform Azure CDN Front Door Profile reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_profile)

[Terraform Azure CDN Front Door Secret reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_secret)

[Terraform Azure CDN Front Door Custom Domain reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_custom_domain)

[Terraform Azure CDN Front Door Endpoint reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_endpoint)

[Terraform Azure CDN Front Door Origin Group reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_origin_group)

[Terraform Azure CDN Front Door Origin reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_origin)

[Terraform Azure CDN Front Door Rule Set reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_rule_set)

[Terraform Azure CDN Front Door Rule reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_rule)

[Terraform Azure CDN Front Door Route reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_route)

[Terraform Azure CDN Front Door Custom Domain Association reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_custom_domain_association)

[Terraform Azure CDN Front Door Firewall Policy reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_firewall_policy)

[Terraform Azure CDN Front Door Security Policy reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_security_policy)
