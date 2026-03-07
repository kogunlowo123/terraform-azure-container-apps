data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_log_analytics_workspace" "existing" {
  count = var.create_log_analytics_workspace ? 0 : (var.log_analytics_workspace_id != null ? 1 : 0)

  name                = split("/", var.log_analytics_workspace_id)[8]
  resource_group_name = split("/", var.log_analytics_workspace_id)[4]
}
