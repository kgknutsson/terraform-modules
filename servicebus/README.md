# Terraform module for deploying Azure Service Bus resources

Use this module to deploy Azure Service Bus resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```hcl
module "eventhub" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/eventhub"

  config         = local.config
  environment    = var.environment
  resource_group = module.resource_group
}
```

## Resources

[Terraform Azure Service Bus Namespace reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_namespace)

[Terraform Azure Service Bus Namespace Authorization Rule reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_namespace_authorization_rule)

[Terraform Azure Service Bus Queue reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_queue)

[Terraform Azure Service Bus Queue Authorization Rule reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_queue_authorization_rule)

[Terraform Azure Service Bus Topic reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_topic)

[Terraform Azure Service Bus Topic Authorization Rule reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_topic_authorization_rule)

[Terraform Azure Service Bus Subscription reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_subscription)

[Terraform Azure Service Bus Subscription Rule reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/servicebus_subscription_rule)
