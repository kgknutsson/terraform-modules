# Terraform module for deploying Azure API management resources

Use this module to deploy Azure API Management resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "api_management" {
  source = "github.com/kgknutsson/terraform-modules?ref=v4/api_management"

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

[Azure API Management Service](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management)

[Azure API Management Service API](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api)

[Azure API Management Service API Operation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api_operation)

[Azure API Management Service API Policy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api_policy)

[Azure API Management Service Backend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_backend)
