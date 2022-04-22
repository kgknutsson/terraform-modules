# Reusable Terraform modules

This repository contains reusable Terraform modules for building Azure resources like App Services, Virtual Networks etc. including all that is needed to run in a live environment. This include all necessary parts for things like connectivity, security, logging, alerting etc.

## Configuration

Modules use configuration that can be loaded from file and then be sent to modules as a variable from the calling root module like this:

```
locals {
  config = yamldecode(file("${path.module}/config.yml"))
}

module "example" {
  config = local.config
}

```

Modules require two additional varables `environment` and `resource_group` and some modules in addition might require other variables as well.

Configuration must have a version set to 1. A global section is needed and as a minimum must set `name` and `location` for resources being created.

Additionally, environment specific configuration can be placed in separate sections denoted by environment name.

All configuration except `name` and `location` can be set in either global or environment specific sections. If set in both, the environment specific settings has a higher priority and will be used.

### Example config.yml file

```
version: 1

global:
  name: example
  location: westeurope
  app_service:
    sku_name: S1
    site_config:
      health_check_path: /actuator/health
    app_settings:
      JAVA_OPTS: -Xms1024m -Xmx1024m

prod:
  app_service:
    sku_name: P1v2

```
In the example above, `sku_name` for all environments will be set to S1 except for **prod** where it will be set to P1v2.
