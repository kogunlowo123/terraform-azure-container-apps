resource "azurerm_resource_group" "test" {
  name     = "rg-containerapp-test"
  location = "eastus2"
}

module "test" {
  source = "../"

  resource_group_name = azurerm_resource_group.test.name
  location            = azurerm_resource_group.test.location
  environment_name    = "cae-test-env"

  create_log_analytics_workspace = true
  log_analytics_workspace_name   = "law-containerapp-test"

  container_apps = {
    api = {
      template = {
        min_replicas = 1
        max_replicas = 3

        containers = [
          {
            name   = "api"
            image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
            cpu    = 0.5
            memory = "1Gi"
          }
        ]
      }

      ingress = {
        external_enabled = true
        target_port      = 80
        transport        = "auto"
      }
    }
  }

  tags = {
    Environment = "test"
    ManagedBy   = "terraform"
  }
}
