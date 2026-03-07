locals {
  common_tags = merge(var.tags, {
    ManagedBy = "Terraform"
    Module    = "terraform-azure-container-apps"
  })

  log_analytics_workspace_name = var.log_analytics_workspace_name != "" ? var.log_analytics_workspace_name : "log-${var.environment_name}"

  log_analytics_workspace_id = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.this[0].id : var.log_analytics_workspace_id

  log_analytics_workspace_primary_key = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.this[0].primary_shared_key : null

  apps_with_ingress = {
    for k, v in var.container_apps : k => v
    if v.ingress != null
  }

  apps_without_ingress = {
    for k, v in var.container_apps : k => v
    if v.ingress == null
  }
}
