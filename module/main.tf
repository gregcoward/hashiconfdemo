provider azurerm {
  version = "~>2.0"
  features {}
}

# AWS Provider
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret
}

# Select the correct zone from Route53
data "aws_route53_zone" "selected" {
  name         = "aserracorp.com."
  private_zone = false
}

#
# Create a random id
#
resource random_id id {
  byte_length = 2
}

#
# Create a resource group
#
resource azurerm_resource_group rg {
  name     = format("%s-rg-%s", var.prefix, random_id.id.hex)
  location = var.location
}

# Reference Existing Network Objects
data "azurerm_virtual_network" "f5-hashiconf-app-vnet" {
  name                = "f5-hashiconf-app-vnet"
  resource_group_name = "f5-hashiconf-rg"
}

data "azurerm_subnet" "controlplane" {
  name                 = "controlplane"
  virtual_network_name = "f5-hashiconf-app-vnet"
  resource_group_name  = "f5-hashiconf-rg"
}

data "azurerm_subnet" "dataplane" {
  name                 = "dataplane"
  virtual_network_name = "f5-hashiconf-app-vnet"
  resource_group_name  = "f5-hashiconf-rg"
}

# Create Log Analytic Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = format("%s-law-%s", var.prefix, random_id.id.hex)
  sku                 = "PerNode"
  retention_in_days   = 300
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_log_analytics_solution" "sentinel" {
  solution_name         = "SecurityInsights"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_resource_id = "${azurerm_log_analytics_workspace.law.id}"
  workspace_name        = "${azurerm_log_analytics_workspace.law.name}"
  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }
}

#
#Create N-nic bigip
#
module bigip {
  count   		= var.instance_count
  source                = "../../"
  prefix 		= format("%s-1nic", var.prefix)
  resource_group_name   = azurerm_resource_group.rg.name
  mgmt_subnet_ids        = [{ "subnet_id" = data.azurerm_subnet.dataplane.id, "public_ip" = true }]
  mgmt_securitygroup_ids = [module.mgmt-network-security-group.network_security_group_id]
  availabilityZones     = var.availabilityZones
}

#
# Create the Network Security group Module to associate with BIGIP-Mgmt-Nic
#
module mgmt-network-security-group {
  source              = "Azure/network-security-group/azurerm"
  resource_group_name = azurerm_resource_group.rg.name
  security_group_name = format("%s-mgmt-nsg-%s", var.prefix, random_id.id.hex)
  tags = {
    environment = "dev"
    costcenter  = "terraform"
  }
}

resource "azurerm_network_security_rule" "mgmt_allow_mgmhttps" {
  name                        = "Allow_Https"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  destination_address_prefix  = "*"
  source_address_prefixes     = var.AllowedIPs
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = format("%s-mgmt-nsg-%s", var.prefix, random_id.id.hex)
  depends_on                  = [module.mgmt-network-security-group]
}
resource "azurerm_network_security_rule" "mgmt_allow_https" {
  name                        = "Allow_Http"
  priority                    = 201
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  destination_address_prefix  = "*"
  source_address_prefixes     = var.AllowedIPs
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = format("%s-mgmt-nsg-%s", var.prefix, random_id.id.hex)
  depends_on                  = [module.mgmt-network-security-group]
}
resource "azurerm_network_security_rule" "mgmt_allow_http" {
  name                        = "Allow_Http"
  priority                    = 201
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  destination_address_prefix  = "*"
  source_address_prefixes     = var.AllowedIPs
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = format("%s-mgmt-nsg-%s", var.prefix, random_id.id.hex)
  depends_on                  = [module.mgmt-network-security-group]
}
resource "azurerm_network_security_rule" "mgmt_allow_ssh" {
  name                        = "Allow_ssh"
  priority                    = 202
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  destination_address_prefix  = "*"
  source_address_prefixes     = var.AllowedIPs
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = format("%s-mgmt-nsg-%s", var.prefix, random_id.id.hex)
  depends_on                  = [module.mgmt-network-security-group]
}

data "template_file" "bigip_do_json" {
  template = file("${path.module}/do.json")

  vars = {
    regKey         = var.license1
    dns_server     = var.dns_server
    ntp_server     = var.ntp_server
    timezone       = var.timezone
    admin_user     = module.bigip.0.f5_username
    admin_password = module.bigip.0.bigip_password
  }
}

data "template_file" "as3_json" {
  template = file("${path.module}/as3.json")

  vars = {
    rg_name         = "f5-hashiconf-rg2"
    subscription_id = var.sp_subscription_id
    tenant_id       = var.sp_tenant_id
    client_id       = var.sp_client_id
    client_secret   = var.sp_client_secret
    publicvip       = "${module.bigip.0.mgmtPublicIP}"
    privatevip      = "0.0.0.0"
  }
}

data "template_file" "ts_json" {
  template   = file("${path.module}/ts.json")

  vars = {
    region      = var.location
    law_id      = azurerm_log_analytics_workspace.law.workspace_id
    law_primkey = azurerm_log_analytics_workspace.law.primary_shared_key
  }
}

# Run REST API for configuration
resource "local_file" "bigip_do_file" {
  content  = data.template_file.bigip_do_json.rendered
  filename = "${path.module}/${var.rest_bigip_do_file}"
}

resource "local_file" "vm_as3_file" {
  content  = data.template_file.as3_json.rendered
  filename = "${path.module}/${var.rest_vm_as3_file}"
}

resource "local_file" "vm_ts_file" {
  content  = data.template_file.ts_json.rendered
  filename = "${path.module}/${var.rest_vm_ts_file}"
}

resource "null_resource" "f5bigip_DO" {
  depends_on = [module.bigip.onboard_do]
  # Running DO REST API
  provisioner "local-exec" {
    command = <<-EOF
      #!/bin/bash
      curl -k -X ${var.rest_do_method} https://${module.bigip.0.mgmtPublicDNS}:8443${var.rest_do_uri} -u ${module.bigip.0.f5_username}:${module.bigip.0.bigip_password} -d @${var.rest_bigip_do_file}
      x=1; while [ $x -le 60 ]; do STATUS=$(curl -s -k -X GET https://${module.bigip.0.mgmtPublicDNS}:8443/mgmt/shared/declarative-onboarding/task -u ${module.bigip.0.f5_username}:${module.bigip.0.bigip_password}); if ( echo $STATUS | grep "OK" ); then break; fi; sleep 10; x=$(( $x + 1 )); done
      sleep 10
    EOF
  }
} 

# Create Route53 DNS entry
resource "aws_route53_record" "myapp" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "myapp.aserracorp.com"
  type    = "A"
  ttl     = "300"
  records = [module.bigip.0.mgmtPublicIP]
}

resource "null_resource" "f5bigip_TS" {
  depends_on = [null_resource.f5bigip_DO]
  # Running TS REST API
  provisioner "local-exec" {
    command = <<-EOF
      #!/bin/bash
      curl -H 'Content-Type: application/json' -k -X POST https://${module.bigip.0.mgmtPublicDNS}:8443${var.rest_ts_uri} -u ${module.bigip.0.f5_username}:${module.bigip.0.bigip_password} -d @${var.rest_vm_ts_file}
    EOF
  }
}

resource "null_resource" "f5bigip_AS3" {
  depends_on = [null_resource.f5bigip_TS]
  # Running AS3 REST API
  provisioner "local-exec" {
    command = <<-EOF
      #!/bin/bash
      curl -k -X ${var.rest_as3_method} https://${module.bigip.0.mgmtPublicDNS}:8443${var.rest_as3_uri} -u ${module.bigip.0.f5_username}:${module.bigip.0.bigip_password} -d @${var.rest_vm_as3_file}
    EOF
  }
}
