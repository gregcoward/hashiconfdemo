# Outputs

output "sg_id" { value = azurerm_network_security_group.f5-hashiconf-sg.id}
output "sg_name" { value = azurerm_network_security_group.f5-hashiconf-sg.name}
output "controlplane_subnet_gw" { value = var.control_gw}
output "datplane_subnet_gw" { value = var.data_gw}
output "Public_VIP_pip" { value = azurerm_public_ip.pubvippip.ip_address}
output "f5bigip_id" { value = azurerm_linux_virtual_machine.f5bigip.id}
output "f5bigip_mgmt_private_ip" { value = azurerm_network_interface.bigip-mgmt-nic.private_ip_address} 
output "f5bigip_mgmt_public_ip" { value = azurerm_public_ip.bigipmgmtpip.ip_address}
output "f5bigip_ext_private_ip" { value = azurerm_network_interface.bigip-ext-nic.private_ip_address}
