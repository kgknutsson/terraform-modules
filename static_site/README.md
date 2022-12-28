# Terraform module for deploying Azure Static Web App resources

Use this module to deploy Azure Static Web App instances with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "static_site" {
  source = "github.com/kgknutsson/terraform-modules?ref=v2/static_site"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group.resource_group_name
}
```

## Configuration

The following configuration can be set in either global or environment specific sections.

```
global:
  ...
  static_site:
    sku_name: <string>
    custom_domains: <string[]>
    tags:
      <string>: <string>
      ...
    sites:
      <string>:
        sku_name: <string>
        custom_domains: <string[]>
        tags:
          <string>: <string>
          ...
      ...
```

## Additional configuration

Some configuration must be applied manually after sites are created.

### Custom domains

Custom domains can be created with this module. However, since the site name is generated on site creation it is not possible to create the required CNAME record before the name is known.

The required steps to add a custom domain are:

1. Create the configuration for setting up the site itself and apply the configuration.
2. Make a note of the auto-created site name and add a CNAME record for the custom domain in DNS.
3. Add the additional configuration for the custom domain and apply a second time to update the previously created site.

### Linking backends

Linking bring-your-own backends can be done using AzureCLI.

```
az staticwebapp backends link -n <Name of static site> -g <Name of resource group> --backend-resource-id <Resource ID of backend>
```

## Resource documentation

[Azure Static Site](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/static_site)

[Azure Static Site Custom Domain](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/static_site_custom_domain)
