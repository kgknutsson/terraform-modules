# Terraform module for deploying Azure Compute resources

Use this module to deploy Azure Compute resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "compute" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/compute"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group
}
```

## Configuration

The following configuration can be set in either global or environment specific sections.

```
global:
  ...
  compute:
    type: <vm|vmss>
    os_type: <Linux|Windows>
    size: <string>
    instances: <int>
    identity:
      type: <SystemAssigned|UserAssigned|SystemAssigned,UserAssigned>
      identity_ids: [<string>]
    subnet_id: <string>
    source_image_reference:
      publisher: <string>
      offer: <string>
      sku: <string>
      version: <string>
    custom_data: <string>
    tags:
      <string>: <string>
      ...
```

## Resource documentation

[Terraform Azure Linux Virtual Machine Scale Set reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set)
