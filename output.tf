
output "resource_group_name" {
  description = "Azure Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "linux_bastion_host_public_ip" {
  description = "Public IP of Linux Bastion Host VM"
  value       = azurerm_public_ip.host_ip.ip_address
}

output "azure_bastion_service_public_ip" {
  description = "Public IP of managed Azure Bastion Service"
  value       = azurerm_public_ip.bastion_service_ip.ip_address
}

output "web_vm_private_ip" {
  description = "Private IP of Web VM"
  value       = azurerm_network_interface.web_nic.private_ip_address
}