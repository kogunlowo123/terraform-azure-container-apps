output "environment_id" {
  description = "Resource ID of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.id
}

output "environment_name" {
  description = "Name of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.name
}

output "environment_default_domain" {
  description = "Default domain of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.default_domain
}

output "environment_static_ip_address" {
  description = "Static IP address of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.static_ip_address
}

output "environment_docker_bridge_cidr" {
  description = "Docker bridge CIDR of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.docker_bridge_cidr
}

output "environment_platform_reserved_cidr" {
  description = "Platform reserved CIDR of the Container Apps Environment."
  value       = azurerm_container_app_environment.this.platform_reserved_cidr
}

output "environment_platform_reserved_dns_ip_address" {
  description = "Platform reserved DNS IP address."
  value       = azurerm_container_app_environment.this.platform_reserved_dns_ip_address
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = local.log_analytics_workspace_id
}

output "container_app_ids" {
  description = "Map of container app names to their resource IDs."
  value       = { for k, v in azurerm_container_app.this : k => v.id }
}

output "container_app_fqdns" {
  description = "Map of container app names to their latest revision FQDNs."
  value       = { for k, v in azurerm_container_app.this : k => try(v.ingress[0].fqdn, null) }
}

output "container_app_outbound_ip_addresses" {
  description = "Map of container app names to their outbound IP addresses."
  value       = { for k, v in azurerm_container_app.this : k => v.outbound_ip_addresses }
}

output "container_app_latest_revision_names" {
  description = "Map of container app names to their latest revision names."
  value       = { for k, v in azurerm_container_app.this : k => v.latest_revision_name }
}

output "dapr_component_ids" {
  description = "Map of Dapr component names to their resource IDs."
  value       = { for k, v in azurerm_container_app_environment_dapr_component.this : k => v.id }
}
