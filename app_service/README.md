# Terraform module for deploying Azure App Service resources

Use this module to deploy Azure App Service resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "app_service" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/app_service"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group

  // Optional
  app_service     = module.app_service_shared
  virtual_network = module.virtual_network
  storage_account = module.storage_account
}
```

## Resources

[Terraform Azure App Service reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service)

[Terraform Azure App Service Plan reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_plan)

[Terraform Azure Application Insights reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights)

[Terraform Azure App Service Virtual Network Association reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection)

[Terraform Azure Relay Namespace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/relay_namespace)

[Terraform Azure Relay Hybrid Connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/relay_hybrid_connection)

[Terraform Azure App Service Hybrid Connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_hybrid_connection)

[Terraform Azure Monitor Metric Alert](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_metric_alert)

[Terraform Azure Monitor Diagnostic Setting](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting)
