provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "rg-container-apps-complete"
  location = "East US"
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-container-apps"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "infrastructure" {
  name                 = "snet-infrastructure"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.0.0/21"]
}

resource "azurerm_storage_account" "example" {
  name                     = "stcaecomplete001"
  location                 = azurerm_resource_group.example.location
  resource_group_name      = azurerm_resource_group.example.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "example" {
  name                 = "config-share"
  storage_account_name = azurerm_storage_account.example.name
  quota                = 5
}

module "container_apps" {
  source = "../../"

  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  environment_name    = "cae-complete-001"

  log_analytics_workspace_name = "log-cae-complete"
  log_analytics_retention_days = 90

  infrastructure_subnet_id       = azurerm_subnet.infrastructure.id
  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = true

  workload_profiles = {
    "dedicated-d4" = {
      workload_profile_type = "D4"
      minimum_count         = 1
      maximum_count         = 3
    }
  }

  environment_storages = {
    "config-storage" = {
      account_name = azurerm_storage_account.example.name
      share_name   = azurerm_storage_share.example.name
      access_key   = azurerm_storage_account.example.primary_access_key
      access_mode  = "ReadOnly"
    }
  }

  container_apps = {
    "web-gateway" = {
      revision_mode = "Multiple"

      template = {
        min_replicas = 2
        max_replicas = 20

        containers = [{
          name   = "gateway"
          image  = "myregistry.azurecr.io/gateway:v2.0"
          cpu    = 1.0
          memory = "2Gi"

          env = [
            { name = "BACKEND_URL", value = "http://api-service" },
            { name = "REDIS_URL", secret_name = "redis-url" }
          ]

          liveness_probe = {
            port             = 8080
            path             = "/healthz"
            initial_delay    = 10
            interval_seconds = 15
          }

          readiness_probe = {
            port             = 8080
            path             = "/ready"
            interval_seconds = 10
          }

          volume_mounts = [{
            name = "config-vol"
            path = "/app/config"
          }]
        }]

        volumes = [{
          name         = "config-vol"
          storage_type = "AzureFile"
          storage_name = "config-storage"
        }]
      }

      ingress = {
        target_port      = 8080
        external_enabled = true
        transport        = "http"

        traffic_weight = [
          { percentage = 80, latest_revision = true },
          { percentage = 20, revision_suffix = "canary", latest_revision = false }
        ]

        ip_security_restriction = [{
          name             = "allow-office"
          ip_address_range = "203.0.113.0/24"
          action           = "Allow"
          description      = "Office network"
        }]
      }

      secrets = [
        { name = "redis-url", value = "redis://redis-cache:6379" },
        { name = "acr-password", value = "registry-password" }
      ]

      registries = [{
        server               = "myregistry.azurecr.io"
        username             = "myregistry"
        password_secret_name = "acr-password"
      }]

      workload_profile_name = "dedicated-d4"
    }

    "api-service" = {
      template = {
        min_replicas = 3
        max_replicas = 15

        containers = [{
          name   = "api"
          image  = "myregistry.azurecr.io/api:v2.0"
          cpu    = 2.0
          memory = "4Gi"

          env = [
            { name = "DB_HOST", secret_name = "db-host" },
            { name = "ASPNETCORE_ENVIRONMENT", value = "Production" }
          ]
        }]
      }

      ingress = {
        target_port      = 5000
        external_enabled = false
        transport        = "http"
      }

      secrets = [
        { name = "db-host", value = "myserver.database.windows.net" },
        { name = "acr-password", value = "registry-password" }
      ]

      registries = [{
        server               = "myregistry.azurecr.io"
        username             = "myregistry"
        password_secret_name = "acr-password"
      }]

      workload_profile_name = "dedicated-d4"
    }

    "worker" = {
      template = {
        min_replicas = 1
        max_replicas = 5

        containers = [{
          name   = "worker"
          image  = "myregistry.azurecr.io/worker:v2.0"
          cpu    = 0.5
          memory = "1Gi"

          env = [
            { name = "QUEUE_URL", secret_name = "queue-url" }
          ]
        }]
      }

      secrets = [
        { name = "queue-url", value = "https://myqueue.servicebus.windows.net" },
        { name = "acr-password", value = "registry-password" }
      ]

      registries = [{
        server               = "myregistry.azurecr.io"
        username             = "myregistry"
        password_secret_name = "acr-password"
      }]
    }
  }

  dapr_components = {
    "statestore" = {
      component_type = "state.azure.cosmosdb"
      version        = "v1"
      scopes         = ["api-service"]

      metadata = [
        { name = "url", value = "https://mycosmos.documents.azure.com:443/" },
        { name = "database", value = "statedb" },
        { name = "collection", value = "state" },
        { name = "masterKey", secret_name = "cosmos-key" }
      ]

      secrets = [{
        name  = "cosmos-key"
        value = "cosmos-master-key"
      }]
    }

    "pubsub" = {
      component_type = "pubsub.azure.servicebus.topics"
      version        = "v1"
      scopes         = ["api-service", "worker"]

      metadata = [
        { name = "connectionString", secret_name = "sb-conn" }
      ]

      secrets = [{
        name  = "sb-conn"
        value = "Endpoint=sb://mybus.servicebus.windows.net/"
      }]
    }
  }

  tags = {
    Environment = "production"
    Project     = "microservices-platform"
    CostCenter  = "APPS-001"
  }
}

output "environment_id" {
  value = module.container_apps.environment_id
}

output "environment_default_domain" {
  value = module.container_apps.environment_default_domain
}

output "environment_static_ip" {
  value = module.container_apps.environment_static_ip_address
}

output "app_fqdns" {
  value = module.container_apps.container_app_fqdns
}

output "app_ids" {
  value = module.container_apps.container_app_ids
}
