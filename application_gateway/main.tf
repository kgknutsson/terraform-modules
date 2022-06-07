locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name           = var.config.global.name
    location       = var.config.global.location

    tags = merge({
      application       = var.config.global.name
      environment       = var.environment
      terraform         = "true"
    }, var.tags)

    sku_name                   = try(local.env_config.application_gateway.sku_name, var.config.global.application_gateway.sku_name, "Standard_v2")
    capacity                   = try(local.env_config.application_gateway.capacity, var.config.global.application_gateway.capacity, 1)

    gateway_ip_configuration = {
      name   = try(local.env_config.application_gateway.gateway_ip_configuration.name, var.config.global.application_gateway.gateway_ip_configuration.name, null)
      subnet = try(local.env_config.application_gateway.gateway_ip_configuration.subnet, var.config.global.application_gateway.gateway_ip_configuration.subnet)
    }

    ssl_policy = {
      policy_name = try(local.env_config.application_gateway.ssl_policy.policy_name, var.config.global.application_gateway.ssl_policy.policy_name, "AppGwSslPolicy20170401S")
      policy_type = try(local.env_config.application_gateway.ssl_policy.policy_type, var.config.global.application_gateway.ssl_policy.policy_type, "Predefined")
    }

    waf_configuration = merge(
      {
        enabled                  = true
        firewall_mode            = "Prevention" // Detection or Prevention
        rule_set_type            = "OWASP"
        rule_set_version         = "3.2"
        file_upload_limit_mb     = null
        request_body_check       = null
        max_request_body_size_kb = null
      },
      try(var.config.global.application_gateway.waf_configuration, {}),
      try(local.env_config.application_gateway.waf_configuration, {})
    )

    public_ip = merge(
      {
        sku               = "Standard" // Basic or Standard
        sku_tier          = "Regional" // Regional or Global
        allocation_method = "Static" // Static or Dynamic
        domain_name_label = null
        zones             = []
      },
      try(var.config.global.application_gateway.public_ip, {}),
      try(local.env_config.application_gateway.public_ip, {})
    )

    frontend_ip_configurations = [
      for v in concat(
        try(var.config.global.application_gateway.frontend_ip_configurations, []),
        try(local.env_config.application_gateway.frontend_ip_configurations, [])
      ) : merge(
        {
          type = "Public"
        },
        v
      )
    ]

    frontend_ports = concat(
      try(var.config.global.application_gateway.frontend_ports, []),
      try(local.env_config.application_gateway.frontend_ports, [])
    )

    ssl_certificates = [
      for v in concat(
        try(var.config.global.application_gateway.ssl_certificates, []),
        try(local.env_config.application_gateway.ssl_certificates, [])
      ) : merge(
        {
          data             = null
          password         = null
          key_vault_secret = null
        },
        v
      )
    ]

    http_listeners = [
      for v in concat(
        try(var.config.global.application_gateway.http_listeners, []),
        try(local.env_config.application_gateway.http_listeners, [])
      ) : merge(
        {
          frontend_ip_configuration = "public"
          frontend_port             = null
          host_name                 = null
          host_names                = null
          require_sni               = null
          ssl_certificate           = null
        },
        v
      )
    ]

    request_routing_rule = [
      for i, v in concat(
        try(var.config.global.application_gateway.request_routing_rules, []),
        try(local.env_config.application_gateway.request_routing_rules, [])
      ) : merge(
        {
          http_listener          = null
          backend_address_pool   = null
          backend_http_settings  = null
          redirect_configuration = null
          rewrite_rule_set       = null
          url_path_map           = null
          priority               = 10010 + i * 10
        },
        v
      )
    ]

    backend_address_pools = [
      for v in concat(
        try(var.config.global.application_gateway.backend_address_pools, []),
        try(local.env_config.application_gateway.backend_address_pools, [])
      ) : merge(
        {
          fqdns        = null
          ip_addresses = null
        },
        v
      )
    ]

    backend_http_settings = [
      for v in concat(
        try(var.config.global.application_gateway.backend_http_settings, []),
        try(local.env_config.application_gateway.backend_http_settings, [])
      ) : merge(
        {
          cookie_based_affinity               = "Disabled"
          affinity_cookie_name                = null
          path                                = null
          port                                = null
          probe                               = null
          protocol                            = "Http"
          request_timeout                     = 60
          host_name                           = null
          pick_host_name_from_backend_address = null
          authentication_certificates         = []
          trusted_root_certificates           = []
          connection_draining                 = null
        },
        v
      )
    ]

    probes = [
      for v in concat(
        try(var.config.global.application_gateway.probes, []),
        try(local.env_config.application_gateway.probes, [])
      ) : merge(
        {
          protocol                                  = "Http"
          port                                      = null
          host                                      = null
          path                                      = "/"
          pick_host_name_from_backend_http_settings = null
          interval                                  = 30
          timeout                                   = 30
          unhealthy_threshold                       = 3
          match                                     = null
          minimum_servers                           = 0
        },
        v
      )
    ]

    authentication_certificates = concat(
        try(var.config.global.application_gateway.authentication_certificates, []),
        try(local.env_config.application_gateway.authentication_certificates, [])
    )

    trusted_root_certificates = concat(
        try(var.config.global.application_gateway.trusted_root_certificates, []),
        try(local.env_config.application_gateway.trusted_root_certificates, [])
    )

    redirect_configurations = [
      for v in concat(
        try(var.config.global.application_gateway.redirect_configurations, []),
        try(local.env_config.application_gateway.redirect_configurations, [])
      ) : merge(
        {
          redirect_type        = "Permanent" // Permanent, Temporary, Found or SeeOther
          target_listener      = null
          target_url           = null
          include_path         = null
          include_query_string = null
        },
        v
      )
    ]

    rewrite_rule_sets = [
      for v in concat(
        try(var.config.global.application_gateway.rewrite_rule_sets, []),
        try(local.env_config.application_gateway.rewrite_rule_sets, [])
      ) : {
        name          = v.name

        rewrite_rules = [
          for v in v.rewrite_rules : merge(
            {
              rule_sequence                  = 100
              conditions                     = []
              request_header_configurations  = []
              response_header_configurations = []
              url                            = null
            },
            v
          )
        ]
      }
    ]

    url_path_maps = [
      for v in concat(
        try(var.config.global.application_gateway.url_path_maps, []),
        try(local.env_config.application_gateway.url_path_maps, [])
      ) : {
        name                           = v.name
        default_backend_address_pool   = try(v.default_backend_address_pool, null)
        default_backend_http_settings  = try(v.default_backend_http_settings, null)
        default_redirect_configuration = try(v.default_redirect_configuration, null)
        default_rewrite_rule_set       = try(v.default_rewrite_rule_set, null)

        path_rules = [
          for v in v.path_rules : merge(
            {
              backend_address_pool   = null
              backend_http_settings  = null
              redirect_configuration = null
              rewrite_rule_set       = null
              firewall_policy_id     = null
            },
            v
          )
        ]
      }
    ]
  }
}

data "azurerm_key_vault_secret" "this" {
  for_each = toset([ for v in concat(local.config.ssl_certificates, local.config.trusted_root_certificates) : coalesce(v.key_vault_secret, v.name) if v.data == null ])

  name         = each.value
  key_vault_id = var.key_vault_id
}

resource "azurecaf_name" "user_assigned_identity" {
  name          = local.config.name
  resource_type = "azurerm_user_assigned_identity"
  suffixes      = [var.environment]
}

resource "azurerm_user_assigned_identity" "this" {
  name                = azurecaf_name.user_assigned_identity.result
  resource_group_name = var.resource_group
  location            = local.config.location
  tags                = local.config.tags
}

resource "azurerm_key_vault_access_policy" "this" {
  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_user_assigned_identity.this.tenant_id
  object_id    = azurerm_user_assigned_identity.this.principal_id

  secret_permissions = [
    "Get",
  ]
}

resource "azurecaf_name" "public_ip" {
  name          = local.config.name
  resource_type = "azurerm_public_ip"
  suffixes      = [var.environment]
}

resource "azurerm_public_ip" "this" {
  name                = azurecaf_name.public_ip.result
  resource_group_name = var.resource_group
  location            = local.config.location
  tags                = local.config.tags
  sku                 = local.config.public_ip.sku
  sku_tier            = local.config.public_ip.sku_tier
  allocation_method   = local.config.public_ip.allocation_method
  domain_name_label   = local.config.public_ip.domain_name_label
  zones               = local.config.public_ip.zones
}

resource "azurecaf_name" "application_gateway" {
  name          = local.config.name
  resource_type = "azurerm_application_gateway"
  suffixes      = [var.environment]
}

resource "azurerm_application_gateway" "this" {
  name                = azurecaf_name.application_gateway.result
  resource_group_name = var.resource_group
  location            = local.config.location
  tags                = local.config.tags

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  sku {
    name     = local.config.sku_name
    tier     = length(regexall("_v2$", local.config.sku_name)) > 0 ? local.config.sku_name : split("_", local.config.sku_name)[0]
    capacity = local.config.capacity
  }

  ssl_policy {
    policy_name = local.config.ssl_policy.policy_name
    policy_type = local.config.ssl_policy.policy_type
  }

  waf_configuration {
    enabled                  = local.config.waf_configuration.enabled
    firewall_mode            = local.config.waf_configuration.firewall_mode
    rule_set_type            = local.config.waf_configuration.rule_set_type
    rule_set_version         = local.config.waf_configuration.rule_set_version
    file_upload_limit_mb     = local.config.waf_configuration.file_upload_limit_mb
    request_body_check       = local.config.waf_configuration.request_body_check
    max_request_body_size_kb = local.config.waf_configuration.max_request_body_size_kb
  }

  gateway_ip_configuration {
    name      = coalesce(local.config.gateway_ip_configuration.name, local.config.gateway_ip_configuration.subnet)
    subnet_id = lookup(var.subnet_ids, local.config.gateway_ip_configuration.subnet)
  }

  dynamic "frontend_ip_configuration" {
    for_each = coalescelist(local.config.frontend_ip_configurations, [{ name = "public", type = "Public" }])

    content {
      name                 = frontend_ip_configuration.value.name
      public_ip_address_id = frontend_ip_configuration.value.type == "Public" ? azurerm_public_ip.this.id : null
    }
  }

  dynamic "frontend_port" {
    for_each = toset(concat(local.config.frontend_ports, [ for v in local.config.http_listeners : { name = null , port = v.ssl_certificate == null ? 80 : 443 } if v.frontend_port == null ]))

    content {
      name = coalesce(frontend_port.value.name, "port${frontend_port.value.port}")
      port = frontend_port.value.port
    }
  }

  dynamic "ssl_certificate" {
    for_each = local.config.ssl_certificates

    content {
      name                = ssl_certificate.value.name
      data                = ssl_certificate.value.data
      password            = ssl_certificate.value.password
      key_vault_secret_id = ssl_certificate.value.data == null ? data.azurerm_key_vault_secret.this[coalesce(ssl_certificate.value.key_vault_secret, ssl_certificate.value.name)].id : null
    }
  }

  dynamic "http_listener" {
    for_each = local.config.http_listeners

    content {
      name                           = http_listener.value.name
      frontend_ip_configuration_name = http_listener.value.frontend_ip_configuration
      frontend_port_name             = coalesce(http_listener.value.frontend_port, "port${http_listener.value.ssl_certificate == null ? 80 : 443}")
      protocol                       = try(http_listener.value.protocol, http_listener.value.ssl_certificate == null ? "Http" : "Https")
      ssl_certificate_name           = http_listener.value.ssl_certificate
      host_name                      = http_listener.value.host_name
      host_names                     = http_listener.value.host_names
    }
  }

  dynamic "request_routing_rule" {
    for_each = local.config.request_routing_rule

    content {
      name                        = request_routing_rule.value.name
      rule_type                   = request_routing_rule.value.url_path_map != null ? "PathBasedRouting" : "Basic"
      http_listener_name          = request_routing_rule.value.http_listener
      backend_address_pool_name   = request_routing_rule.value.backend_address_pool
      backend_http_settings_name  = request_routing_rule.value.backend_http_settings
      redirect_configuration_name = request_routing_rule.value.redirect_configuration
      rewrite_rule_set_name       = request_routing_rule.value.rewrite_rule_set
      url_path_map_name           = request_routing_rule.value.url_path_map
      priority                    = request_routing_rule.value.priority
    }
  }

  dynamic "backend_address_pool" {
    for_each = local.config.backend_address_pools

    content {
      name         = backend_address_pool.value.name
      fqdns        = backend_address_pool.value.fqdns
      ip_addresses = backend_address_pool.value.ip_addresses
    }
  }

  dynamic "backend_http_settings" {
    for_each = local.config.backend_http_settings

    content {
      name                                = backend_http_settings.value.name
      cookie_based_affinity               = backend_http_settings.value.cookie_based_affinity
      affinity_cookie_name                = backend_http_settings.value.affinity_cookie_name
      path                                = backend_http_settings.value.path
      port                                = coalesce(backend_http_settings.value.port, backend_http_settings.value.protocol == "Http" ? 80 : 443)
      probe_name                          = backend_http_settings.value.probe
      protocol                            = backend_http_settings.value.protocol
      request_timeout                     = backend_http_settings.value.request_timeout
      host_name                           = backend_http_settings.value.host_name
      pick_host_name_from_backend_address = backend_http_settings.value.pick_host_name_from_backend_address
      trusted_root_certificate_names      = backend_http_settings.value.trusted_root_certificates

      dynamic "authentication_certificate" {
        for_each = backend_http_settings.value.authentication_certificates

        content {
          name = authentication_certificate.value.name
        }
      }

      dynamic "connection_draining" {
        for_each = backend_http_settings.value.connection_draining[*]

        content {
          enabled = connection_draining.value.enabled
          drain_timeout_sec = connection_draining.value.drain_timeout_sec
        }
      }
    }
  }

  dynamic "probe" {
    for_each = local.config.probes

    content {
      name                                      = probe.value.name
      protocol                                  = probe.value.protocol
      host                                      = probe.value.host
      path                                      = probe.value.path
      pick_host_name_from_backend_http_settings = coalesce(probe.value.pick_host_name_from_backend_http_settings, probe.value.host == null ? true : false)
      interval                                  = probe.value.interval
      timeout                                   = probe.value.timeout
      unhealthy_threshold                       = probe.value.unhealthy_threshold

      dynamic "match" {
        for_each = probe.value.match[*]

        content {
          body        = match.value.body
          status_code = match.value.status_code
        }
      }
    }
  }

  dynamic "authentication_certificate" {
    for_each = local.config.authentication_certificates

    content {
      name = authentication_certificate.value.name
      data = authentication_certificate.value.data
    }
  }

  dynamic "trusted_root_certificate" {
    for_each = local.config.trusted_root_certificates

    content {
      name                = trusted_root_certificate.value.name
      data                = trusted_root_certificate.value.data
      key_vault_secret_id = trusted_root_certificate.value.data == null ? data.azurerm_key_vault_secret.this[trusted_root_certificate.value.name].id : null
    }
  }

  dynamic "redirect_configuration" {
    for_each = local.config.redirect_configurations

    content {
      name                 = redirect_configuration.value.name
      redirect_type        = redirect_configuration.value.redirect_type
      target_listener_name = redirect_configuration.value.target_listener
      target_url           = redirect_configuration.value.target_url
      include_path         = redirect_configuration.value.include_path
      include_query_string = redirect_configuration.value.include_query_string
    }
  }

  dynamic "rewrite_rule_set" {
    for_each = local.config.rewrite_rule_sets

    content {
      name = rewrite_rule_set.value.name

      dynamic "rewrite_rule" {
        for_each = rewrite_rule_set.value.rewrite_rules

        content {
          name          = rewrite_rule.value.name
          rule_sequence = rewrite_rule.value.rule_sequence

          dynamic "condition" {
            for_each = rewrite_rule.value.conditions

            content {
              variable    = condition.value.variable
              pattern     = condition.value.pattern
              ignore_case = try(condition.value.ignore_case, false)
              negate      = try(condition.value.negate, false)
            }
          }

          dynamic "request_header_configuration" {
            for_each = rewrite_rule.value.request_header_configurations

            content {
              header_name  = request_header_configuration.value.header_name
              header_value = request_header_configuration.value.header_value
            }
          }

          dynamic "response_header_configuration" {
            for_each = rewrite_rule.value.response_header_configurations

            content {
              header_name  = response_header_configuration.value.header_name
              header_value = response_header_configuration.value.header_value
            }
          }

          dynamic "url" {
            for_each = rewrite_rule.value.url[*]

            content {
              path         = try(url.value.path, null)
              query_string = try(url.value.query_string, null)
              reroute      = try(url.value.reroute, null)
            }
          }
        }
      }
    }
  }

  dynamic "url_path_map" {
    for_each = local.config.url_path_maps

    content {
      name                                = url_path_map.value.name
      default_backend_address_pool_name   = url_path_map.value.default_backend_address_pool
      default_backend_http_settings_name  = url_path_map.value.default_backend_http_settings
      default_redirect_configuration_name = url_path_map.value.default_redirect_configuration
      default_rewrite_rule_set_name       = url_path_map.value.default_rewrite_rule_set

      dynamic "path_rule" {
        for_each = url_path_map.value.path_rules

        content {
          name                        = path_rule.value.name
          paths                       = path_rule.value.paths
          backend_address_pool_name   = path_rule.value.backend_address_pool
          backend_http_settings_name  = path_rule.value.backend_http_settings
          redirect_configuration_name = path_rule.value.redirect_configuration
          rewrite_rule_set_name       = path_rule.value.rewrite_rule_set
          firewall_policy_id          = path_rule.value.firewall_policy_id
        }
      }
    }
  }
}
