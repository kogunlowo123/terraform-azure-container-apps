provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "rg-container-apps-advanced"
  location = "East US"
}

module "container_apps" {
  source = "../../"

  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  environment_name    = "cae-advanced-001"

  log_analytics_workspace_name = "log-cae-advanced"
  log_analytics_retention_days = 60

  container_apps = {
    "web-frontend" = {
      revision_mode = "Multiple"

      template = {
        min_replicas = 1
        max_replicas = 5

        containers = [{
          name   = "frontend"
          image  = "myregistry.azurecr.io/frontend:v1.0"
          cpu    = 0.5
          memory = "1Gi"

          env = [
            { name = "API_URL", value = "https://api.internal" },
            { name = "NODE_ENV", value = "production" }
          ]

          liveness_probe = {
            port = 3000
            path = "/healthz"
          }

          readiness_probe = {
            port = 3000
            path = "/ready"
          }
        }]
      }

      ingress = {
        target_port      = 3000
        external_enabled = true
        traffic_weight = [{
          percentage      = 100
          latest_revision = true
        }]
      }
    }

    "api-backend" = {
      template = {
        min_replicas = 2
        max_replicas = 10

        containers = [{
          name   = "api"
          image  = "myregistry.azurecr.io/api:v1.0"
          cpu    = 1.0
          memory = "2Gi"

          env = [
            { name = "DB_CONNECTION", secret_name = "db-connection" }
          ]
        }]
      }

      ingress = {
        target_port      = 8080
        external_enabled = false
      }

      secrets = [{
        name  = "db-connection"
        value = "Server=tcp:myserver.database.windows.net;Database=mydb;"
      }]
    }
  }

  dapr_components = {
    "statestore" = {
      component_type = "state.azure.blobstorage"
      version        = "v1"
      scopes         = ["api-backend"]

      metadata = [
        { name = "accountName", value = "mystatestore" },
        { name = "containerName", value = "state" },
        { name = "accountKey", secret_name = "storage-key" }
      ]

      secrets = [{
        name  = "storage-key"
        value = "your-storage-key"
      }]
    }
  }

  tags = {
    Environment = "staging"
    Project     = "microservices"
  }
}

output "environment_id" {
  value = module.container_apps.environment_id
}

output "app_fqdns" {
  value = module.container_apps.container_app_fqdns
}
