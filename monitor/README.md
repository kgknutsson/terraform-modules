# Terraform module for deploying Azure Monitor resources

Use this module to deploy Azure Monitor resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "monitor" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/monitor"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group
  monitor_config = <A map containing lists of autoscale settings, diagnostic settings and/or metric alerts.>
}
```
