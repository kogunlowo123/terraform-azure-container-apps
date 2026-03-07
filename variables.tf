variable "resource_group_name" {
  description = "Name of the resource group where resources will be created."
  type        = string

  validation {
    condition     = length(var.resource_group_name) > 0 && length(var.resource_group_name) <= 90
    error_message = "Resource group name must be between 1 and 90 characters."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "environment_name" {
  description = "Name of the Container Apps Environment."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,58}[a-zA-Z0-9]$", var.environment_name))
    error_message = "Environment name must start with a letter, end with alphanumeric, be 2-60 characters, and contain only letters, numbers, and hyphens."
  }
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace for the environment. If not provided, a new one will be created."
  type        = string
  default     = null
}

variable "create_log_analytics_workspace" {
  description = "Whether to create a new Log Analytics workspace."
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Name for the Log Analytics workspace if creating one."
  type        = string
  default     = ""
}

variable "log_analytics_sku" {
  description = "SKU for the Log Analytics workspace."
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Retention period in days for Log Analytics workspace."
  type        = number
  default     = 30

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "Retention days must be between 30 and 730."
  }
}

variable "infrastructure_subnet_id" {
  description = "Resource ID of the subnet for VNet injection. The subnet must have a /21 or larger CIDR."
  type        = string
  default     = null
}

variable "internal_load_balancer_enabled" {
  description = "Whether the environment only has an internal load balancer (no public ingress)."
  type        = bool
  default     = false
}

variable "zone_redundancy_enabled" {
  description = "Whether zone redundancy is enabled for the Container Apps Environment."
  type        = bool
  default     = false
}

variable "workload_profiles" {
  description = "Map of workload profiles for the environment."
  type = map(object({
    workload_profile_type = string
    minimum_count         = number
    maximum_count         = number
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.workload_profiles : contains([
        "D4", "D8", "D16", "D32", "E4", "E8", "E16", "E32"
      ], v.workload_profile_type)
    ])
    error_message = "Workload profile type must be one of: D4, D8, D16, D32, E4, E8, E16, E32."
  }
}

variable "container_apps" {
  description = "Map of container apps to deploy."
  type = map(object({
    revision_mode = optional(string, "Single")

    template = object({
      min_replicas    = optional(number, 0)
      max_replicas    = optional(number, 10)
      revision_suffix = optional(string, null)

      containers = list(object({
        name    = string
        image   = string
        cpu     = number
        memory  = string
        command = optional(list(string), [])
        args    = optional(list(string), [])

        env = optional(list(object({
          name        = string
          value       = optional(string, null)
          secret_name = optional(string, null)
        })), [])

        liveness_probe = optional(object({
          transport               = optional(string, "HTTP")
          port                    = number
          path                    = optional(string, "/healthz")
          initial_delay           = optional(number, 5)
          interval_seconds        = optional(number, 10)
          failure_count_threshold = optional(number, 3)
        }), null)

        readiness_probe = optional(object({
          transport               = optional(string, "HTTP")
          port                    = number
          path                    = optional(string, "/ready")
          interval_seconds        = optional(number, 10)
          failure_count_threshold = optional(number, 3)
        }), null)

        volume_mounts = optional(list(object({
          name = string
          path = string
        })), [])
      }))

      volumes = optional(list(object({
        name         = string
        storage_type = optional(string, "EmptyDir")
        storage_name = optional(string, null)
      })), [])
    })

    ingress = optional(object({
      external_enabled = optional(bool, true)
      target_port      = number
      transport        = optional(string, "auto")
      allow_insecure   = optional(bool, false)

      traffic_weight = optional(list(object({
        percentage      = number
        label           = optional(string, null)
        latest_revision = optional(bool, true)
        revision_suffix = optional(string, null)
      })), [{ percentage = 100, latest_revision = true }])

      ip_security_restriction = optional(list(object({
        name             = string
        ip_address_range = string
        action           = string
        description      = optional(string, "")
      })), [])
    }), null)

    secrets = optional(list(object({
      name  = string
      value = string
    })), [])

    registries = optional(list(object({
      server               = string
      username             = optional(string, null)
      password_secret_name = optional(string, null)
      identity             = optional(string, null)
    })), [])

    workload_profile_name = optional(string, null)
    tags                  = optional(map(string), {})
  }))
  default = {}
}

variable "dapr_components" {
  description = "Map of Dapr components for the environment."
  type = map(object({
    component_type = string
    version        = string
    ignore_errors  = optional(bool, false)
    init_timeout   = optional(string, "5s")
    scopes         = optional(list(string), [])

    metadata = optional(list(object({
      name        = string
      value       = optional(string, null)
      secret_name = optional(string, null)
    })), [])

    secrets = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = {}
}

variable "custom_domains" {
  description = "Map of custom domain configurations for container apps."
  type = map(object({
    container_app_name     = string
    name                   = string
    certificate_binding_type = optional(string, "SniEnabled")
    container_app_environment_certificate_id = optional(string, null)
  }))
  default = {}
}

variable "managed_certificates" {
  description = "Map of managed certificates for the environment."
  type = map(object({
    custom_domain_name   = string
    dns_txt_token_value  = optional(string, null)
  }))
  default = {}
}

variable "environment_storages" {
  description = "Map of storage mounts for the environment."
  type = map(object({
    account_name = string
    share_name   = string
    access_key   = string
    access_mode  = optional(string, "ReadOnly")
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
