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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azurecaf"></a> [azurecaf](#requirement\_azurecaf) | >= 1.2.19 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.72.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurecaf"></a> [azurecaf](#provider\_azurecaf) | >= 1.2.19 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 3.72.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurecaf_name.api_management](https://registry.terraform.io/providers/aztfmod/azurecaf/latest/docs/resources/name) | resource |
| [azurerm_api_management.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management) | resource |
| [azurerm_api_management_api.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api) | resource |
| [azurerm_api_management_api_diagnostic.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api_diagnostic) | resource |
| [azurerm_api_management_api_operation.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api_operation) | resource |
| [azurerm_api_management_api_operation_policy.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api_operation_policy) | resource |
| [azurerm_api_management_api_policy.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_api_policy) | resource |
| [azurerm_api_management_backend.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_backend) | resource |
| [azurerm_api_management_diagnostic.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_diagnostic) | resource |
| [azurerm_api_management_logger.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_logger) | resource |
| [azurerm_api_management_product.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_product) | resource |
| [azurerm_api_management_product_api.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_product_api) | resource |
| [azurerm_api_management_product_policy.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_product_policy) | resource |
| [azurerm_api_management_subscription.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_subscription) | resource |
| [azurerm_api_management_user.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/api_management_user) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_service"></a> [app\_service](#input\_app\_service) | (Optional) Shared app service resources.<br><br>App Service resources created outside this module. | <pre>object({<br>    application_insights_resource_id       = optional(string)<br>    application_insights_connection_string = optional(string)<br>  })</pre> | `null` | no |
| <a name="input_config"></a> [config](#input\_config) | (Required) Module configuration (version 1).<br>Configuration should have global settings and preferably environment specific settings for dev, prod etc. | `any` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | (Required) Environment name.<br>Must be a single short word, all lowercase, eg. dev. | `string` | n/a | yes |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | (Required) Resource group to create new resources in.<br><br>Resource Group resources created outside this module. | <pre>object({<br>    id       = string<br>    name     = string<br>    location = string<br>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | (Optional) Tags to add to resources created by the module.<br>Tags are key-value pair strings that can be used to categorise and group resources. The module add som tags by defalt which cannot be set manually (application, environment and terraform). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_monitor_config"></a> [monitor\_config](#output\_monitor\_config) | n/a |
| <a name="output_public_ip_addresses"></a> [public\_ip\_addresses](#output\_public\_ip\_addresses) | Public IP addresses |
<!-- END_TF_DOCS -->