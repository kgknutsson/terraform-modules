# Terraform module for Azure App Service configuration

This module configures an Azure App Service instance with Terraform.

## Resources

[Terraform Azure App Service reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service)

[Terraform Azure App Service Plan reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_plan)

[Terraform Azure Application Insights reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights)

[Terraform Azure App Service Virtual Network Association reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection)

[Terraform Azure Relay Namespace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/relay_namespace)

[Terraform Azure Relay Hybrid Connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/relay_hybrid_connection)

[Terraform Azure App Service Hybrid Connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_hybrid_connection)

[Terraform Azure Monitor Metric Alert](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_metric_alert)


// TODO: Jag hade förklarat varför du har delat upp app service i tre olika "main" filer, så man förstår varför man behöver main.tf, metrica_alerts.tf och hybrid_connections.tf.