locals {
  env_config = lookup(var.config, var.environment, {})

  config = {
    name                = var.config.global.name
    location            = var.resource_group.location
    resource_group_name = var.resource_group.name

    naming = {
      for i in [
        "azurerm_cdn_frontdoor_profile",
        "azurerm_cdn_frontdoor_secret",
        "azurerm_cdn_frontdoor_endpoint",
        "azurerm_cdn_frontdoor_firewall_policy",
        "azurerm_cdn_frontdoor_security_policy",
      ] : i => merge(
        {
          name          = var.config.global.name
          prefixes      = null
          suffixes      = compact([var.environment])
          random_length = null
          use_slug      = null
        },
        try(lookup(var.config.global.cdn_frontdoor.naming, i), {}),
        try(lookup(local.env_config.cdn_frontdoor.naming, i), {})
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
      try(var.config.global.cdn_frontdoor.tags, {}),
      try(local.env_config.cdn_frontdoor.tags, {})
    )

    sku_name = try(local.env_config.cdn_frontdoor.sku_name, var.config.global.cdn_frontdoor.sku_name, null) // Standard_AzureFrontDoor or Premium_AzureFrontDoor

    secrets = {
      for k in setunion(
        try(keys(local.env_config.cdn_frontdoor.custom_domains), []),
        try(keys(var.config.global.cdn_frontdoor.custom_domains), [])
      ) : k => try(
        local.env_config.cdn_frontdoor.custom_domains[k].tls.key_vault_certificate_id,
        var.config.global.cdn_frontdoor.custom_domains[k].tls.key_vault_certificate_id
      ) if can(try(
        local.env_config.cdn_frontdoor.custom_domains[k].tls.key_vault_certificate_id,
        var.config.global.cdn_frontdoor.custom_domains[k].tls.key_vault_certificate_id
      ))
    }

    custom_domains = {
      for k in setunion(
        try(keys(local.env_config.cdn_frontdoor.custom_domains), []),
        try(keys(var.config.global.cdn_frontdoor.custom_domains), []),
        try(keys(local.env_config.cdn_frontdoor.rule_sets["redirects"]), []),
        try(keys(var.config.global.cdn_frontdoor.rule_sets["redirects"]), []),
        flatten([ for k, v in try(local.env_config.cdn_frontdoor.routes, {}) : try(v.custom_domains, []) ]),
        flatten([ for k, v in try(var.config.global.cdn_frontdoor.routes, {}) : try(v.custom_domains, []) ])
      ) : replace(k, ".", "-") => merge(
        {
          host_name = try(local.env_config.cdn_frontdoor.custom_domains[k], var.config.global.cdn_frontdoor.custom_domains[k], null) == null ? k : replace(k, "-", ".")
        },
        try(local.env_config.cdn_frontdoor.custom_domains[k], {}),
        try(var.config.global.cdn_frontdoor.custom_domains[k], {}),
        {
          tls = merge(
            {
              minimum_tls_version      = null // TLS10 or TLS12, defaults to TLS12
              key_vault_certificate_id = null
            },
            try(local.env_config.cdn_frontdoor.custom_domains[k].tls, {}),
            try(var.config.global.cdn_frontdoor.custom_domains[k].tls, {}),
          )
        }
      )
    }

    endpoints = {
      for k in setunion(
        try(keys(local.env_config.cdn_frontdoor.endpoints), local.env_config.cdn_frontdoor.endpoints, []),
        try(keys(var.config.global.cdn_frontdoor.endpoints), var.config.global.cdn_frontdoor.endpoints, []),
      ) : k => {
        enabled = try(
          local.env_config.cdn_frontdoor.endpoints[k].enabled,
          local.env_config.cdn_frontdoor.endpoints[k],
          var.config.global.cdn_frontdoor.endpoints[k].enabled,
          var.config.global.cdn_frontdoor.endpoints[k],
          true
        )
      }
    }

    origin_groups = {
      for k in setunion(
        try(keys(local.env_config.cdn_frontdoor.origin_groups), []),
        try(keys(var.config.global.cdn_frontdoor.origin_groups), []),
        [ for k, v in try(local.env_config.cdn_frontdoor.origins, {}) : v.origin_group if can(v.origin_group) ],
        [ for k, v in try(var.config.global.cdn_frontdoor.origins, {}) : v.origin_group if can(v.origin_group) ]
      ) : k => merge(
        {
          restore_traffic_time_to_healed_or_new_endpoint_in_minutes = null // Value between 0 and 50 minutes, defaults to 10
          session_affinity_enabled                                  = null // Defaults to true
          health_probe                                              = null
        },
        try(local.env_config.cdn_frontdoor.origin_groups[k], {}),
        try(var.config.global.cdn_frontdoor.origin_groups[k], {}),
        {
          load_balancing = merge(
            {
              additional_latency_in_milliseconds = null // Value between 0 and 1000 milliseconds, defaults to 50
              sample_size                        = null // Value between 0 and 255, defaults to 4
              successful_samples_required        = null // Value between 0 and 255, defaults to 3
            },
            try(local.env_config.cdn_frontdoor.origin_groups[k].load_balancing, {}),
            try(var.config.global.cdn_frontdoor.origin_groups[k].load_balancing, {}),
          )
        }
      )
    }

    origins = {
      for k in setunion(
        try(keys(local.env_config.cdn_frontdoor.origins), []),
        try(keys(var.config.global.cdn_frontdoor.origins), [])
      ) : k => merge(
        {
          origin_group                   = null
          host_name                      = null
          certificate_name_check_enabled = true
          enabled                        = true
          http_port                      = 80
          https_port                     = 443
          origin_host_header             = null
          priority                       = 1
          weight                         = 1000
        },
        try(local.env_config.cdn_frontdoor.origins[k], {}),
        try(var.config.global.cdn_frontdoor.origins[k], {}),
      )
    }

    rule_sets = {
      for k in setunion(
        try(keys(local.env_config.cdn_frontdoor.rule_sets), []),
        try(keys(var.config.global.cdn_frontdoor.rule_sets), [])
      ) : k => merge(
        {
          for x, y in merge(
            try(local.env_config.cdn_frontdoor.rule_sets[k], {}),
            try(var.config.global.cdn_frontdoor.rule_sets[k], {})
          ) : x => y if k != "redirects"
        },
        {
          for x, y in {
            for n, m in merge(
              try(local.env_config.cdn_frontdoor.rule_sets[k], {}),
              try(var.config.global.cdn_frontdoor.rule_sets[k], {})
            ) : n => regex("^(?P<redirect_protocol>[^:/?#]+)://(?P<destination_hostname>[^/?#]*)(?P<destination_path>[^?#]*)?[?]?(?P<query_string>[^#]*)?#?(?P<destination_fragment>.*)?", m) if k == "redirects"
          } : replace(x, ".", "-") => {
            actions = {
              url_redirect_action = {
                redirect_type        = "Moved"
                redirect_protocol    = title(y.redirect_protocol)
                destination_hostname = y.destination_hostname
                destination_path     = trimsuffix(y.destination_path, "/") == "" ? null : y.destination_path
                query_string         = y.query_string == "" ? null : y.query_string
                destination_fragment = y.destination_fragment == "" ? null : y.destination_fragment
              }
            }
            conditions = {
              host_name_condition = {
                match_values = [x]
              }
            }
          }
        }
      )
    }

    routes = {
      for k in setunion(
        try(keys(local.env_config.cdn_frontdoor.routes), []),
        try(keys(var.config.global.cdn_frontdoor.routes), [])
      ) : k => merge(
        {
          endpoint               = null
          origin_group           = null
          origins                = []
          rule_sets              = []
          custom_domains         = []
          origin_path            = null
          enabled                = true
          forwarding_protocol    = "HttpsOnly"
          https_redirect_enabled = true
          patterns_to_match      = ["/*"]
          supported_protocols    = ["Http", "Https"]
          link_to_default_domain = true
          cache                  = null
        },
        try(local.env_config.cdn_frontdoor.routes[k], {}),
        try(var.config.global.cdn_frontdoor.routes[k], {})
      )
    }

    firewall_policies = {
      for k in setunion(
        try(keys(local.env_config.cdn_frontdoor.firewall_policies), []),
        try(keys(var.config.global.cdn_frontdoor.firewall_policies), [])
      ) : k => merge(
        {
          sku_name = null
          mode     = null
        },
        try(local.env_config.cdn_frontdoor.firewall_policies[k], {}),
        try(var.config.global.cdn_frontdoor.firewall_policies[k], {}),
      )
    }

    security_policies = {
      for k in setunion(
        try(keys(local.env_config.cdn_frontdoor.security_policies), []),
        try(keys(var.config.global.cdn_frontdoor.security_policies), [])
      ) : k => merge(
        {
          name              = null
          firewall_policy   = null
          patterns_to_match = ["/*"]
          domains           = []
        },
        try(local.env_config.cdn_frontdoor.security_policies[k], {}),
        try(var.config.global.cdn_frontdoor.security_policies[k], {}),
      )
    }
  }
}

resource "azurecaf_name" "cdn_frontdoor_profile" {
  count = length(local.config.sku_name[*])

  name          = local.config.naming["azurerm_cdn_frontdoor_profile"].name
  resource_type = "azurerm_cdn_frontdoor_profile"
  prefixes      = local.config.naming["azurerm_cdn_frontdoor_profile"].prefixes
  suffixes      = local.config.naming["azurerm_cdn_frontdoor_profile"].suffixes
  random_length = local.config.naming["azurerm_cdn_frontdoor_profile"].random_length
  use_slug      = local.config.naming["azurerm_cdn_frontdoor_profile"].use_slug
}

resource "azurerm_cdn_frontdoor_profile" "this" {
  count = length(local.config.sku_name[*])

  name                     = azurecaf_name.cdn_frontdoor_profile[0].result
  resource_group_name      = local.config.resource_group_name
  sku_name                 = local.config.sku_name
  tags                     = local.config.tags
  response_timeout_seconds = 60
}

data "azurerm_key_vault_certificate" "this" {
  for_each = { for k, v in local.config.secrets : k => v if length(regexall("^[\\w-]+$", v)) > 0 }

  name         = each.value
  key_vault_id = var.key_vault.id
}

resource "azurecaf_name" "cdn_frontdoor_secret" {
  for_each = { for k, v in local.config.secrets : k => v if length(local.config.sku_name[*]) > 0 }

  resource_type = "azurerm_cdn_frontdoor_secret"
  name          = local.config.naming["azurerm_cdn_frontdoor_secret"].name
  prefixes      = local.config.naming["azurerm_cdn_frontdoor_secret"].prefixes
  suffixes      = concat(local.config.naming["azurerm_cdn_frontdoor_secret"].suffixes, [each.key])
  random_length = local.config.naming["azurerm_cdn_frontdoor_secret"].random_length
  use_slug      = local.config.naming["azurerm_cdn_frontdoor_secret"].use_slug
}

resource "azurerm_cdn_frontdoor_secret" "this" {
  for_each = { for k, v in local.config.secrets : k => v if length(local.config.sku_name[*]) > 0 }

  name                     = azurecaf_name.cdn_frontdoor_secret[each.key].result
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this[0].id

  secret {
    customer_certificate {
      key_vault_certificate_id = try(data.azurerm_key_vault_certificate.this[each.value].versionless_id, each.value)
    }
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "this" {
  for_each = { for k, v in local.config.custom_domains : k => v if length(local.config.sku_name[*]) > 0 }

  name                     = each.key
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this[0].id
  host_name                = each.value.host_name

  tls {
    certificate_type        = each.value.tls.key_vault_certificate_id == null ? "ManagedCertificate" : "CustomerCertificate"
    minimum_tls_version     = each.value.tls.minimum_tls_version
    cdn_frontdoor_secret_id = each.value.tls.key_vault_certificate_id != null ? azurerm_cdn_frontdoor_secret.this[each.key].id : null
  }
}

resource "azurecaf_name" "cdn_frontdoor_endpoint" {
  for_each = { for k, v in local.config.endpoints : k => v if length(local.config.sku_name[*]) > 0 }

  resource_type = "azurerm_cdn_frontdoor_endpoint"
  name          = each.key
  prefixes      = local.config.naming["azurerm_cdn_frontdoor_endpoint"].prefixes
  suffixes      = local.config.naming["azurerm_cdn_frontdoor_endpoint"].suffixes
  random_length = local.config.naming["azurerm_cdn_frontdoor_endpoint"].random_length
  use_slug      = local.config.naming["azurerm_cdn_frontdoor_endpoint"].use_slug
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  for_each = { for k, v in local.config.endpoints : k => v if length(local.config.sku_name[*]) > 0 }

  name                     = azurecaf_name.cdn_frontdoor_endpoint[each.key].result
  cdn_frontdoor_profile_id = replace(azurerm_cdn_frontdoor_profile.this[0].id, "resourcegroups", "resourceGroups")
  enabled                  = each.value.enabled
  tags                     = local.config.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "this" {
  for_each = { for k, v in local.config.origin_groups : k => v if length(local.config.sku_name[*]) > 0 }

  name                                                      = each.key
  cdn_frontdoor_profile_id                                  = replace(azurerm_cdn_frontdoor_profile.this[0].id, "resourcegroups", "resourceGroups")
  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = each.value.restore_traffic_time_to_healed_or_new_endpoint_in_minutes
  session_affinity_enabled                                  = each.value.session_affinity_enabled

  load_balancing {
    additional_latency_in_milliseconds = each.value.load_balancing.additional_latency_in_milliseconds
    sample_size                        = each.value.load_balancing.sample_size
    successful_samples_required        = each.value.load_balancing.successful_samples_required
  }

  dynamic "health_probe" {
    for_each = [
      for i in each.value.health_probe[*] : merge(
        {
          protocol            = "Https" // Http or Https
          interval_in_seconds = 30 // Value between 5 and 31536000 seconds
          request_type        = null // HEAD or GET, defaults to HEAD
          path                = null // Defaults to "/"
        },
        i
      )
    ]

    content {
      protocol            = health_probe.value.protocol
      interval_in_seconds = health_probe.value.interval_in_seconds
      request_type        = health_probe.value.request_type
      path                = health_probe.value.path
    }
  }
}

resource "azurerm_cdn_frontdoor_origin" "this" {
  for_each = { for k, v in local.config.origins : k => v if length(local.config.sku_name[*]) > 0 }

  name                           = each.key
  cdn_frontdoor_origin_group_id  = replace(azurerm_cdn_frontdoor_origin_group.this[each.value.origin_group].id, "resourcegroups", "resourceGroups")
  host_name                      = each.value.host_name
  certificate_name_check_enabled = each.value.certificate_name_check_enabled
  enabled                        = each.value.enabled
  http_port                      = each.value.http_port
  https_port                     = each.value.https_port
  origin_host_header             = coalesce(each.value.origin_host_header, each.value.host_name)
  priority                       = each.value.priority
  weight                         = each.value.weight
}

resource "azurerm_cdn_frontdoor_rule_set" "this" {
  for_each = toset([ for k, v in local.config.rule_sets : k if length(local.config.sku_name[*]) > 0 ])

  name                     = each.key
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this[0].id
}

resource "azurerm_cdn_frontdoor_rule" "this" {
  for_each = merge([
    for k, v in local.config.rule_sets : {
      for x, y in v : x => merge(
        {
          order             = try(y.conditions, null) == null ? 0 : index(keys(v), x) + 1
          rule_set          = k
          conditions        = null
          behavior_on_match = null
        },
        y,
        {
          actions = merge(
            {
              url_rewrite_action                  = null
              url_redirect_action                 = null
              route_configuration_override_action = null
              request_header_action               = null
              response_header_action              = null
            },
            try(y.actions, {})
          )
        }
      )
    } if length(local.config.sku_name[*]) > 0
  ]...)

  name                      = replace(each.key, "-", "")
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.this[each.value.rule_set].id
  order                     = each.value.order
  behavior_on_match         = each.value.behavior_on_match

  actions {
    dynamic "url_redirect_action" {
      for_each = each.value.actions.url_redirect_action[*]

      content {
        destination_hostname = try(url_redirect_action.value.destination_hostname, "")
        destination_path     = try(url_redirect_action.value.destination_path, null)
        query_string         = try(url_redirect_action.value.query_string, null)
        destination_fragment = try(url_redirect_action.value.destination_fragment, null)
        redirect_type        = try(url_redirect_action.value.redirect_type, "Moved")
        redirect_protocol    = try(url_redirect_action.value.redirect_protocol, "Https")
      }
    }

    #TODO: Add more dynamic actions
  }

  dynamic "conditions" {
    for_each = each.value.conditions[*]

    content {
      dynamic "host_name_condition" {
        for_each = try(conditions.value.host_name_condition[*], {})

        content {
          operator         = try(host_name_condition.value.operator, "Equal")
          match_values     = try(host_name_condition.value.match_values, [])
          transforms       = try(host_name_condition.value.transforms, null)
          negate_condition = try(host_name_condition.value.negate_condition, null)
        }
      }

      dynamic "request_uri_condition" {
        for_each = try(conditions.value.request_uri_condition[*], {})

        content {
          operator         = try(request_uri_condition.value.operator, "Equal")
          match_values     = try(request_uri_condition.value.match_values, [])
          transforms       = try(request_uri_condition.value.transforms, null)
          negate_condition = try(request_uri_condition.value.negate_condition, null)
        }
      }

      #TODO: Add dynamics for all different types of conditions
    }
  }

  depends_on = [azurerm_cdn_frontdoor_origin_group.this, azurerm_cdn_frontdoor_origin.this]
}

resource "azurerm_cdn_frontdoor_route" "this" {
  for_each = { for k, v in local.config.routes : k => v if length(local.config.sku_name[*]) > 0 }

  name                            = each.key
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.this[each.value.endpoint].id
  cdn_frontdoor_origin_group_id   = replace(azurerm_cdn_frontdoor_origin_group.this[each.value.origin_group].id, "resourcegroups", "resourceGroups")
  cdn_frontdoor_origin_ids        = [ for k, v in azurerm_cdn_frontdoor_origin.this : v.id if contains(each.value.origins, k) ]
  cdn_frontdoor_rule_set_ids      = [ for k, v in azurerm_cdn_frontdoor_rule_set.this : v.id if contains(each.value.rule_sets, k) ]
  cdn_frontdoor_custom_domain_ids = [ for k, v in azurerm_cdn_frontdoor_custom_domain.this : v.id if contains(each.value.custom_domains, k) || contains(each.value.custom_domains, v.host_name) ]
  cdn_frontdoor_origin_path       = each.value.origin_path
  enabled                         = each.value.enabled
  forwarding_protocol             = each.value.forwarding_protocol
  https_redirect_enabled          = each.value.https_redirect_enabled
  patterns_to_match               = each.value.patterns_to_match
  supported_protocols             = each.value.supported_protocols
  link_to_default_domain          = each.value.link_to_default_domain

  dynamic "cache" {
    for_each = [
      for i in each.value.cache[*] : merge(
        {
          compression_enabled           = false
          content_types_to_compress     = yamldecode(file("${path.module}/default_content_types_to_compress.yml"))
          query_string_caching_behavior = "UseQueryString"
          query_strings                 = []
        },
        i
      )
    ]

    content {
      compression_enabled           = cache.value.compression_enabled
      content_types_to_compress     = cache.value.content_types_to_compress
      query_string_caching_behavior = cache.value.query_string_caching_behavior
      query_strings                 = cache.value.query_strings
    }
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "this" {
  for_each = transpose({ for k, v in local.config.routes : k => [ for i in v.custom_domains : replace(i, ".", "-") ] if length(local.config.sku_name[*]) > 0 })

  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.this[each.key].id
  cdn_frontdoor_route_ids        = [ for i in each.value : azurerm_cdn_frontdoor_route.this[i].id ]
}

resource "azurecaf_name" "cdn_frontdoor_firewall_policy" {
  for_each = { for k, v in local.config.firewall_policies : k => v if length(local.config.sku_name[*]) > 0 }

  resource_type = "azurerm_cdn_frontdoor_firewall_policy"
  name          = local.config.naming["azurerm_cdn_frontdoor_firewall_policy"].name
  prefixes      = local.config.naming["azurerm_cdn_frontdoor_firewall_policy"].prefixes
  suffixes      = concat(local.config.naming["azurerm_cdn_frontdoor_firewall_policy"].suffixes, [each.key])
  random_length = local.config.naming["azurerm_cdn_frontdoor_firewall_policy"].random_length
  use_slug      = local.config.naming["azurerm_cdn_frontdoor_firewall_policy"].use_slug
}

resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  for_each = { for k, v in local.config.firewall_policies : k => v if length(local.config.sku_name[*]) > 0 }

  name                = azurecaf_name.cdn_frontdoor_firewall_policy[each.key].result
  resource_group_name = local.config.resource_group_name
  tags                = local.config.tags
  sku_name            = each.value.sku_name
  mode                = each.value.mode

  dynamic "managed_rule" {
    for_each = each.value.managed_rules

    content {
      action  = managed_rule.value.action
      type    = managed_rule.value.type
      version = managed_rule.value.version
    }
  }
}

resource "azurecaf_name" "cdn_frontdoor_security_policy" {
  for_each = { for k, v in local.config.security_policies : k => v if length(local.config.sku_name[*]) > 0 }

  resource_type = "azurerm_cdn_frontdoor_security_policy"
  name          = local.config.naming["azurerm_cdn_frontdoor_security_policy"].name
  prefixes      = local.config.naming["azurerm_cdn_frontdoor_security_policy"].prefixes
  suffixes      = concat(local.config.naming["azurerm_cdn_frontdoor_security_policy"].suffixes, [each.key])
  random_length = local.config.naming["azurerm_cdn_frontdoor_security_policy"].random_length
  use_slug      = local.config.naming["azurerm_cdn_frontdoor_security_policy"].use_slug
}

resource "azurerm_cdn_frontdoor_security_policy" "this" {
  for_each = { for k, v in local.config.security_policies : k => v if length(local.config.sku_name[*]) > 0 }

  name                     = azurecaf_name.cdn_frontdoor_security_policy[each.key].result
  cdn_frontdoor_profile_id = replace(azurerm_cdn_frontdoor_profile.this[0].id, "resourcegroups", "resourceGroups")

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = try(azurerm_cdn_frontdoor_firewall_policy.this[each.value.firewall_policy].id, each.value.firewall_policy)

      association {
        patterns_to_match = each.value.patterns_to_match

        dynamic "domain" {
          for_each = each.value.domains

          content {
            cdn_frontdoor_domain_id = domain.value != null ? try(azurerm_cdn_frontdoor_endpoint.this[domain.value].id, azurerm_cdn_frontdoor_custom_domain.this[domain.value].id) : null
          }
        }
      }
    }
  }
}
