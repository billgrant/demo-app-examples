output "resource_group" {
  description = "Name of the Azure resource group"
  value       = azurerm_resource_group.demo.name
}

output "container_fqdn" {
  description = "Fully qualified domain name of the container"
  value       = azurerm_container_group.demo_app.fqdn
}

output "app_url" {
  description = "URL to access the demo app"
  value       = "http://${azurerm_container_group.demo_app.fqdn}:8080"
}

output "system_info" {
  description = "System info captured at initial apply (from display panel)"
  value       = jsondecode(demoapp_display.system_snapshot.data)
}

output "items_created" {
  description = "IDs of the items created"
  value = {
    terraform = demoapp_item.terraform.id
    azure     = demoapp_item.azure.id
  }
}
