resource "azurerm_log_analytics_workspace" "this" {
  count = var.create_log_analytics_workspace ? 1 : 0

  name                = var.log_analytics_workspace_name != "" ? var.log_analytics_workspace_name : "log-${var.environment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days

  tags = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                           = var.environment_name
  location                       = var.location
  resource_group_name            = var.resource_group_name
  log_analytics_workspace_id     = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.this[0].id : var.log_analytics_workspace_id
  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = var.internal_load_balancer_enabled
  zone_redundancy_enabled        = var.zone_redundancy_enabled

  dynamic "workload_profile" {
    for_each = var.workload_profiles
    content {
      name                  = workload_profile.key
      workload_profile_type = workload_profile.value.workload_profile_type
      minimum_count         = workload_profile.value.minimum_count
      maximum_count         = workload_profile.value.maximum_count
    }
  }

  tags = var.tags
}

resource "azurerm_container_app_environment_storage" "this" {
  for_each = var.environment_storages

  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.this.id
  account_name                 = each.value.account_name
  share_name                   = each.value.share_name
  access_key                   = each.value.access_key
  access_mode                  = each.value.access_mode
}

resource "azurerm_container_app_environment_certificate" "managed" {
  for_each = var.managed_certificates

  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.this.id
  certificate_blob_base64      = ""
  certificate_password         = ""
}

resource "azurerm_container_app" "this" {
  for_each = var.container_apps

  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = var.resource_group_name
  revision_mode                = each.value.revision_mode
  workload_profile_name        = each.value.workload_profile_name

  template {
    min_replicas    = each.value.template.min_replicas
    max_replicas    = each.value.template.max_replicas
    revision_suffix = each.value.template.revision_suffix

    dynamic "container" {
      for_each = each.value.template.containers
      content {
        name    = container.value.name
        image   = container.value.image
        cpu     = container.value.cpu
        memory  = container.value.memory
        command = length(container.value.command) > 0 ? container.value.command : null
        args    = length(container.value.args) > 0 ? container.value.args : null

        dynamic "env" {
          for_each = container.value.env
          content {
            name        = env.value.name
            value       = env.value.value
            secret_name = env.value.secret_name
          }
        }

        dynamic "liveness_probe" {
          for_each = container.value.liveness_probe != null ? [container.value.liveness_probe] : []
          content {
            transport               = liveness_probe.value.transport
            port                    = liveness_probe.value.port
            path                    = liveness_probe.value.path
            initial_delay           = liveness_probe.value.initial_delay
            interval_seconds        = liveness_probe.value.interval_seconds
            failure_count_threshold = liveness_probe.value.failure_count_threshold
          }
        }

        dynamic "readiness_probe" {
          for_each = container.value.readiness_probe != null ? [container.value.readiness_probe] : []
          content {
            transport               = readiness_probe.value.transport
            port                    = readiness_probe.value.port
            path                    = readiness_probe.value.path
            interval_seconds        = readiness_probe.value.interval_seconds
            failure_count_threshold = readiness_probe.value.failure_count_threshold
          }
        }

        dynamic "volume_mounts" {
          for_each = container.value.volume_mounts
          content {
            name = volume_mounts.value.name
            path = volume_mounts.value.path
          }
        }
      }
    }

    dynamic "volume" {
      for_each = each.value.template.volumes
      content {
        name         = volume.value.name
        storage_type = volume.value.storage_type
        storage_name = volume.value.storage_name
      }
    }
  }

  dynamic "ingress" {
    for_each = each.value.ingress != null ? [each.value.ingress] : []
    content {
      external_enabled          = ingress.value.external_enabled
      target_port               = ingress.value.target_port
      transport                 = ingress.value.transport
      allow_insecure_connections = ingress.value.allow_insecure

      dynamic "traffic_weight" {
        for_each = ingress.value.traffic_weight
        content {
          percentage      = traffic_weight.value.percentage
          label           = traffic_weight.value.label
          latest_revision = traffic_weight.value.latest_revision
          revision_suffix = traffic_weight.value.revision_suffix
        }
      }

      dynamic "ip_security_restriction" {
        for_each = ingress.value.ip_security_restriction
        content {
          name             = ip_security_restriction.value.name
          ip_address_range = ip_security_restriction.value.ip_address_range
          action           = ip_security_restriction.value.action
          description      = ip_security_restriction.value.description
        }
      }
    }
  }

  dynamic "secret" {
    for_each = each.value.secrets
    content {
      name  = secret.value.name
      value = secret.value.value
    }
  }

  dynamic "registry" {
    for_each = each.value.registries
    content {
      server               = registry.value.server
      username             = registry.value.username
      password_secret_name = registry.value.password_secret_name
      identity             = registry.value.identity
    }
  }

  tags = merge(var.tags, each.value.tags)
}

resource "azurerm_container_app_environment_dapr_component" "this" {
  for_each = var.dapr_components

  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.this.id
  component_type               = each.value.component_type
  version                      = each.value.version
  ignore_errors                = each.value.ignore_errors
  init_timeout                 = each.value.init_timeout
  scopes                       = each.value.scopes

  dynamic "metadata" {
    for_each = each.value.metadata
    content {
      name        = metadata.value.name
      value       = metadata.value.value
      secret_name = metadata.value.secret_name
    }
  }

  dynamic "secret" {
    for_each = each.value.secrets
    content {
      name  = secret.value.name
      value = secret.value.value
    }
  }
}

resource "azurerm_container_app_custom_domain" "this" {
  for_each = var.custom_domains

  name             = each.value.name
  container_app_id = azurerm_container_app.this[each.value.container_app_name].id

  certificate_binding_type                 = each.value.certificate_binding_type
  container_app_environment_certificate_id = each.value.container_app_environment_certificate_id
}
