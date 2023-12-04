# Terraform module for deploying Azure SQL Database resources

Use this module to deploy Azure SQL Database resources with Terraform.

## Usage

Add the module to a terraform root module by adding these lines of code.

```
module "mssql_database" {
  source = "github.com/kgknutsson/terraform-modules?ref=v3/mssql_database"

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
  mssql_database:
    naming:
      <string>:
        name: <string>
        prefixes: [<string>,...]
        suffixes: [<string>,...]
        random_length: <int>
        use_slug: <bool>
    version: <string>
    minimum_tls_version: <string>
    public_network_access_enabled: <bool>
    elastic_pools:
      <string>:
        max_size_gb: <int>
    default_maintenance_configuration_name: <string>
    default_max_gb_size: <int>
    default_sku_name: <string>
    default_elastic_pool: <string>
    databases:
      <string>:
        create_mode: <string>
        creation_source_database_id: <string>
        collation: <string>
        maintenance_configuration_name: <string>
        license_type: <string>
        max_size_gb: <int>
        read_scale: <bool>
        sku_name: <string>
        elastic_pool: <string>
        zone_redundant: <bool>
        weekly_retention: <string>
        monthly_retention: <string>
        yearly_retention: <string>
        week_of_year: <string>
        user_assigned_identity: <bool>
        tags:
          <string>: <string>
          ...
        instances:
          <string>:
            create_mode: <string>
            creation_source_database_id: <string>
            collation: <string>
            maintenance_configuration_name: <string>
            license_type: <string>
            max_size_gb: <int>
            read_scale: <bool>
            sku_name: <string>
            elastic_pool: <string>
            zone_redundant: <bool>
            weekly_retention: <string>
            monthly_retention: <string>
            yearly_retention: <string>
            week_of_year: <string>
            user_assigned_identity: <bool>
            tags:
              <string>: <string>
              ...
    tags:
      <string>: <string>
      ...
```

## Resource documentation

[Terraform Azure SQL Server reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_server)

[Terraform Azure SQL Elastic Pool reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_elasticpool)

[Terraform Azure SQL Database reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_database)

[Terraform Azure User Assigned Identity reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity)
