locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    location            = var.resource_group.location
    resource_group_name = var.resource_group.name

    naming = {
      for i in ["azurerm_api_management"] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = compact([var.environment])
          random_length = null
          use_slug      = null
        },
        try(lookup(var.config.global.mssql_database.naming, i), {}),
        try(lookup(local.env_config.mssql_database.naming, i), {})
      )
    }

    tags = merge(
      {
        application = var.config.global.name
        environment = var.environment
        terraform   = "true"
      },
      var.tags,
      try(var.config.global.tags, {}),
      try(local.env_config.tags, {}),
      try(var.config.global.api_management.tags, {}),
      try(local.env_config.api_management.tags, {})
    )

    sku_name        = try(local.env_config.api_management.sku_name, var.config.global.api_management.sku_name, null)
    publisher_name  = try(local.env_config.api_management.publisher_name, var.config.global.api_management.publisher_name, null)
    publisher_email = try(local.env_config.api_management.publisher_email, var.config.global.api_management.publisher_email, null)

    apis = {
      for k in keys(merge(
        try(var.config.global.api_management.apis, {}),
        try(local.env_config.api_management.apis, {})
      )) : k => merge(
        {
          revision      = 1
          api_type      = "http" // graphql, http, soap or websocket
          source_api_id = null // api_resource.id or api_resource.id;rev=<revision>
          display_name  = title(k)
          path          = null
          protocols     = ["https"] // http, https, ws and wss
          import        = null
          policy        = null
          diagnostic    = null
          operations    = []
          products      = []
        },
        try(var.config.global.api_management.apis[k], {}),
        try(local.env_config.api_management.apis[k], {})
      )
    }

    products = {
      for k in keys(merge(
        try(var.config.global.api_management.products, {}),
        try(local.env_config.api_management.products, {})
      )) : k => merge(
        {
          apis = []
        },
        try(var.config.global.api_management.products[k], {}),
        try(local.env_config.api_management.products[k], {})
      )
    }

    backends = {
      for k in keys(merge(
        try(var.config.global.api_management.backends, {}),
        try(local.env_config.api_management.backends, {})
      )) : k => merge(
        {
          description = null
          protocol    = "http" //http or soap
          url         = null
          resource_id = null
        },
        try(var.config.global.api_management.backends[k], {}),
        try(local.env_config.api_management.backends[k], {})
      )
    }

    loggers = {
      for k in keys(merge(
        try(var.config.global.api_management.loggers, {}),
        try(local.env_config.api_management.loggers, {})
      )) : k => merge(
        {
          resource_id          = try(var.app_service.application_insights_resource_id, null)
          description          = null
          buffered             = null
          application_insights = null
        },
        try(var.config.global.api_management.loggers[k], {}),
        try(local.env_config.api_management.loggers[k], {})
      )
    }

    diagnostic = merge(
      {
        logger_id                 = null
        identifier                = "applicationinsights"
        always_log_errors         = null
        http_correlation_protocol = null
        log_client_ip             = null
        operation_name_format     = null
        sampling_percentage       = null
        verbosity                 = null
        backend_request           = null
        backend_response          = null
        frontend_request          = null
        frontend_response         = null
      },
      try(local.env_config.api_management.diagnostic, {}),
      try(var.config.global.api_management.diagnostic, {})
    )
  }

  default_api_operations = [
    for i in ["DELETE", "GET", "HEAD", "OPTIONS", "PATH", "POST", "PUT", "TRACE"] : {
      method       = i
      url_template = "/*"
    }
  ]
}

resource "azurecaf_name" "api_management" {
  name           = local.config.naming["azurerm_api_management"].name
  resource_type  = "azurerm_api_management"
  prefixes       = local.config.naming["azurerm_api_management"].prefixes
  suffixes       = local.config.naming["azurerm_api_management"].suffixes
  random_length  = local.config.naming["azurerm_api_management"].random_length
  use_slug       = local.config.naming["azurerm_api_management"].use_slug
}

resource "azurerm_api_management" "this" {
  name                = azurecaf_name.api_management.result
  resource_group_name = local.config.resource_group_name
  location            = local.config.location
  tags                = local.config.tags
  sku_name            = local.config.sku_name
  publisher_name      = local.config.publisher_name
  publisher_email     = local.config.publisher_email

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_api_management_api" "this" {
  for_each = local.config.apis

  api_management_name = azurerm_api_management.this.name
  resource_group_name = local.config.resource_group_name
  name                = each.key
  revision            = each.value.revision
  api_type            = each.value.api_type
  source_api_id       = each.value.source_api_id
  display_name        = each.value.display_name
  path                = each.value.path
  protocols           = each.value.protocols

  dynamic "import" {
    for_each = each.value.import[*]

    content {
      content_format = import.value.content_format // openapi, openapi+json, openapi+json-link, openapi-link, swagger-json, swagger-link-json, wadl-link-json, wadl-xml, wsdl or wsdl-link
      content_value  = try(startswith(import.value.content_value, "file:") ? file(format("%s/%s", path.root, split(":", import.value.content_value)[1])) : import.value.content_value, null)

      dynamic "wsdl_selector" {
        for_each = try(import.value.wsdl_selector[*], [])

        content {
          service_name  = wsdl_selector.value.service_name
          endpoint_name = wsdl_selector.value.endpoint_name
        }
      }
    }
  }
}

resource "azurerm_api_management_api_diagnostic" "this" {
  for_each = {
    for k, v in local.config.apis : k => merge(
      {
        identifier                = "applicationinsights"
        always_log_errors         = null
        http_correlation_protocol = null
        log_client_ip             = null
        operation_name_format     = null
        sampling_percentage       = null
        verbosity                 = null
        backend_request           = null
        backend_response          = null
        frontend_request          = null
        frontend_response         = null
      },
      v.diagnostic
    ) if v.diagnostic != null
  }
  
  api_name                  = azurerm_api_management_api.this[each.key].name
  api_management_name       = azurerm_api_management.this.name
  api_management_logger_id  = try(azurerm_api_management_logger.this[each.value.logger_id].id, each.value.logger_id)
  resource_group_name       = local.config.resource_group_name
  identifier                = each.value.identifier
  always_log_errors         = each.value.always_log_errors
  http_correlation_protocol = each.value.http_correlation_protocol
  log_client_ip             = each.value.log_client_ip
  operation_name_format     = each.value.operation_name_format
  sampling_percentage       = each.value.sampling_percentage
  verbosity                 = each.value.verbosity

  dynamic "backend_request" {
    for_each = each.value.backend_request[*]

    content {
      body_bytes     = try(backend_request.value.body_bytes, null)
      headers_to_log = try(backend_request.value.headers_to_log, null)

      dynamic "data_masking" {
        for_each = try(backend_request.value.data_masking[*], [])

        content {
          dynamic "headers" {
            for_each = try(data_masking.value.headers[*], [])

            content {
              mode  = headers.value.mode
              value = headers.value.value
            }
          }

          dynamic "query_params" {
            for_each = try(data_masking.value.query_params[*], [])

            content {
              mode  = query_params.value.mode
              value = query_params.value.value
            }
          }
        }
      }
    }
  }

  dynamic "backend_response" {
    for_each = each.value.backend_response[*]

    content {
      body_bytes     = try(backend_response.value.body_bytes, null)
      headers_to_log = try(backend_response.value.headers_to_log, null)

      dynamic "data_masking" {
        for_each = try(backend_response.value.data_masking[*], [])

        content {
          dynamic "headers" {
            for_each = try(data_masking.value.headers[*], [])

            content {
              mode  = headers.value.mode
              value = headers.value.value
            }
          }

          dynamic "query_params" {
            for_each = try(data_masking.value.query_params[*], [])

            content {
              mode  = query_params.value.mode
              value = query_params.value.value
            }
          }
        }
      }
    }
  }

  dynamic "frontend_request" {
    for_each = each.value.frontend_request[*]

    content {
      body_bytes     = try(frontend_request.value.body_bytes, null)
      headers_to_log = try(frontend_request.value.headers_to_log, null)

      dynamic "data_masking" {
        for_each = try(frontend_request.value.data_masking[*], [])

        content {
          dynamic "headers" {
            for_each = try(data_masking.value.headers[*], [])

            content {
              mode  = headers.value.mode
              value = headers.value.value
            }
          }

          dynamic "query_params" {
            for_each = try(data_masking.value.query_params[*], [])

            content {
              mode  = query_params.value.mode
              value = query_params.value.value
            }
          }
        }
      }
    }
  }

  dynamic "frontend_response" {
    for_each = each.value.frontend_response[*]

    content {
      body_bytes     = try(frontend_response.value.body_bytes, null)
      headers_to_log = try(frontend_response.value.headers_to_log, null)

      dynamic "data_masking" {
        for_each = try(frontend_response.value.data_masking[*], [])

        content {
          dynamic "headers" {
            for_each = try(data_masking.value.headers[*], [])

            content {
              mode  = headers.value.mode
              value = headers.value.value
            }
          }

          dynamic "query_params" {
            for_each = try(data_masking.value.query_params[*], [])

            content {
              mode  = query_params.value.mode
              value = query_params.value.value
            }
          }
        }
      }
    }
  }
}

resource "azurerm_api_management_api_operation" "this" {
  for_each = merge([
    for k, v in local.config.apis : {
      for o in coalescelist(
        v.operations,
        local.default_api_operations
      ) : join("_", [k, coalesce(try(o.operation_id, null), o.method)]) => merge({ api_name = k }, o)
    } if v.import == null
  ]...) 

  api_management_name = azurerm_api_management.this.name
  resource_group_name = local.config.resource_group_name
  api_name            = each.value.api_name
  operation_id        = try(each.value.operation_id, each.key)
  display_name        = try(each.value.display_name, each.key)
  method              = each.value.method
  url_template        = try(each.value.url_template, "/*")
}

resource "azurerm_api_management_api_policy" "this" {
  for_each = { for k, v in local.config.apis : k => v.policy if v.policy != null }

  api_management_name = azurerm_api_management.this.name
  resource_group_name = local.config.resource_group_name
  api_name            = each.key
  xml_content         = try(startswith(each.value.xml_content, "file:") ? file(format("%s/%s", path.root, split(":", each.value.xml_content)[1])) : each.value.xml_content, null)
  xml_link            = try(each.value.xml_link, null)
}

resource "azurerm_api_management_product_api" "this" {
  for_each = merge(concat(
    [
      for k, v in local.config.apis : {
        for i in v.products : join("_", [i, k]) => {
          product_id = i
          api_name   = k
        }
      }
    ],
    [
      for k, v in local.config.products : {
        for i in v.apis : join("_", [k, i]) => {
          product_id = k
          api_name   = i
        }
      }
    ]
  )...)

  api_management_name = azurerm_api_management.this.name
  resource_group_name = local.config.resource_group_name
  product_id          = each.value.product_id
  api_name            = each.value.api_name
}

resource "azurerm_api_management_backend" "this" {
  for_each = local.config.backends

  api_management_name = azurerm_api_management.this.name
  resource_group_name = local.config.resource_group_name
  name                = each.key
  description         = try(coalesce(each.value.description, split("/", each.value.resource_id)[8]), null)
  protocol            = each.value.protocol
  url                 = coalesce(each.value.url, format("https://%s.azurewebsites.net", split("/", each.value.resource_id)[8]))
  resource_id         = try("https://management.azure.com${each.value.resource_id}", null)
}

resource "azurerm_api_management_logger" "this" {
  for_each = local.config.loggers

  api_management_name = azurerm_api_management.this.name
  resource_group_name = local.config.resource_group_name
  name                = each.key
  description         = each.value.description
  resource_id         = each.value.resource_id
  buffered            = each.value.buffered

  dynamic "application_insights" {
    for_each = each.value.application_insights[*]

    content {
      instrumentation_key = try(
        application_insights.value.instrumentation_key,
        regex("(?:InstrumentationKey=)(?P<instrumentation_key>.+?)(?:;)", var.app_service.application_insights_connection_string).instrumentation_key
      )
    }
  }
}

resource "azurerm_api_management_diagnostic" "this" {
  count = local.config.diagnostic.logger_id != null ? 1 : 0

  api_management_name       = azurerm_api_management.this.name
  api_management_logger_id  = try(azurerm_api_management_logger.this[local.config.diagnostic.logger_id].id, local.config.diagnostic.logger_id)
  resource_group_name       = local.config.resource_group_name
  identifier                = local.config.diagnostic.identifier
  always_log_errors         = local.config.diagnostic.always_log_errors
  http_correlation_protocol = local.config.diagnostic.http_correlation_protocol
  log_client_ip             = local.config.diagnostic.log_client_ip
  operation_name_format     = local.config.diagnostic.operation_name_format
  sampling_percentage       = local.config.diagnostic.sampling_percentage
  verbosity                 = local.config.diagnostic.verbosity

  dynamic "backend_request" {
    for_each = local.config.diagnostic.backend_request[*]

    content {
      body_bytes     = try(backend_request.value.body_bytes, null)
      headers_to_log = try(backend_request.value.headers_to_log, null)

      dynamic "data_masking" {
        for_each = try(backend_request.value.data_masking[*], [])

        content {
          dynamic "headers" {
            for_each = try(data_masking.value.headers[*], [])

            content {
              mode  = headers.value.mode
              value = headers.value.value
            }
          }

          dynamic "query_params" {
            for_each = try(data_masking.value.query_params[*], [])

            content {
              mode  = query_params.value.mode
              value = query_params.value.value
            }
          }
        }
      }
    }
  }

  dynamic "backend_response" {
    for_each = local.config.diagnostic.backend_response[*]

    content {
      body_bytes     = try(backend_response.value.body_bytes, null)
      headers_to_log = try(backend_response.value.headers_to_log, null)

      dynamic "data_masking" {
        for_each = try(backend_response.value.data_masking[*], [])

        content {
          dynamic "headers" {
            for_each = try(data_masking.value.headers[*], [])

            content {
              mode  = headers.value.mode
              value = headers.value.value
            }
          }

          dynamic "query_params" {
            for_each = try(data_masking.value.query_params[*], [])

            content {
              mode  = query_params.value.mode
              value = query_params.value.value
            }
          }
        }
      }
    }
  }

  dynamic "frontend_request" {
    for_each = local.config.diagnostic.frontend_request[*]

    content {
      body_bytes     = try(frontend_request.value.body_bytes, null)
      headers_to_log = try(frontend_request.value.headers_to_log, null)

      dynamic "data_masking" {
        for_each = try(frontend_request.value.data_masking[*], [])

        content {
          dynamic "headers" {
            for_each = try(data_masking.value.headers[*], [])

            content {
              mode  = headers.value.mode
              value = headers.value.value
            }
          }

          dynamic "query_params" {
            for_each = try(data_masking.value.query_params[*], [])

            content {
              mode  = query_params.value.mode
              value = query_params.value.value
            }
          }
        }
      }
    }
  }

  dynamic "frontend_response" {
    for_each = local.config.diagnostic.frontend_response[*]

    content {
      body_bytes     = try(frontend_response.value.body_bytes, null)
      headers_to_log = try(frontend_response.value.headers_to_log, null)

      dynamic "data_masking" {
        for_each = try(frontend_response.value.data_masking[*], [])

        content {
          dynamic "headers" {
            for_each = try(data_masking.value.headers[*], [])

            content {
              mode  = headers.value.mode
              value = headers.value.value
            }
          }

          dynamic "query_params" {
            for_each = try(data_masking.value.query_params[*], [])

            content {
              mode  = query_params.value.mode
              value = query_params.value.value
            }
          }
        }
      }
    }
  }
}
