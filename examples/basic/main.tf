provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "rg-container-apps-basic"
  location = "East US"
}

module "container_apps" {
  source = "../../"

  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  environment_name    = "cae-basic-001"

  container_apps = {
    "api" = {
      template = {
        containers = [{
          name   = "api"
          image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
          cpu    = 0.25
          memory = "0.5Gi"
        }]
      }
      ingress = {
        target_port = 80
      }
    }
  }

  tags = {
    Environment = "development"
  }
}

output "environment_id" {
  value = module.container_apps.environment_id
}

output "app_fqdns" {
  value = module.container_apps.container_app_fqdns
}
