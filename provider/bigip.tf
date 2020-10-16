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

# Create Public IPs
resource "azurerm_public_ip" "bigipmgmtpip" {
  name                = "${var.prefix}-bigip-mgmt-pip"
  location            = azurerm_resource_group.f5-hashiconf-rg2.location
  sku                 = "Standard"
  resource_group_name = azurerm_resource_group.f5-hashiconf-rg2.name
  allocation_method   = "Static"

  tags = {
    Name        = "${var.environment}-bigip-mgmt-public-ip"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

resource "azurerm_public_ip" "bigipselfpip" {
  name                = "${var.prefix}-bigip-self-pip"
  location            = azurerm_resource_group.f5-hashiconf-rg2.location
  sku                 = "Standard"
  resource_group_name = azurerm_resource_group.f5-hashiconf-rg2.name
  allocation_method   = "Static"

  tags = {
    Name        = "${var.environment}-bigip-self-public-ip"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

resource "azurerm_public_ip" "pubvippip" {
  name                = "${var.prefix}-pubvip-pip"
  location            = azurerm_resource_group.f5-hashiconf-rg2.location
  sku                 = "Standard"
  resource_group_name = azurerm_resource_group.f5-hashiconf-rg2.name
  allocation_method   = "Static"

  tags = {
    Name        = "${var.environment}-pubvip-public-ip"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

# Create Route53 DNS entry
resource "aws_route53_record" "myapp" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "myapp.aserracorp.com"
  type    = "A"
  ttl     = "300"
  allow_overwrite = true
  records = [azurerm_public_ip.pubvippip.ip_address]
}

# Create a Network Security Group and rules
resource "azurerm_network_security_group" "f5-hashiconf-sg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.f5-hashiconf-rg2.location
  resource_group_name = azurerm_resource_group.f5-hashiconf-rg2.name

  security_rule {
    name                       = "allow_SSH"
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_HTTP"
    description                = "Allow HTTP access"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_HTTPS"
    description                = "Allow HTTPS access"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_APP_HTTPS"
    description                = "Allow HTTPS access"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Name        = "${var.environment}-bigip-sg"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

# Create NIC for Management 
resource "azurerm_network_interface" "bigip-mgmt-nic" {
  name                = "${var.prefix}-mgmt0"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.f5-hashiconf-rg2.name
  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.controlplane.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5bigipmgmt
    public_ip_address_id          = azurerm_public_ip.bigipmgmtpip.id
  }

  tags = {
    Name        = "${var.environment}-bigip-mgmt-int"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

# Create NIC for External
resource "azurerm_network_interface" "bigip-ext-nic" {
  name                 = "${var.prefix}-ext0"
  location             = azurerm_resource_group.f5-hashiconf-rg2.location
  resource_group_name  = azurerm_resource_group.f5-hashiconf-rg2.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = data.azurerm_subnet.dataplane.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5bigipext
    primary                       = true
    public_ip_address_id          = azurerm_public_ip.bigipselfpip.id
  }

  ip_configuration {
    name                          = "secondary1"
    subnet_id                     = data.azurerm_subnet.dataplane.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5privatevip
  }

  ip_configuration {
    name                          = "secondary2"
    subnet_id                     = data.azurerm_subnet.dataplane.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.f5publicvip
    public_ip_address_id          = azurerm_public_ip.pubvippip.id
  }

  tags = {
    Name                      = "${var.environment}-bigip-ext-int"
    environment               = var.environment
    owner                     = var.owner
    group                     = var.group
    costcenter                = var.costcenter
    application               = var.application
  }
}

# Associate network security groups with NICs
resource "azurerm_network_interface_security_group_association" "bigip-mgmt-nsg" {
  network_interface_id      = azurerm_network_interface.bigip-mgmt-nic.id

  network_security_group_id = azurerm_network_security_group.f5-hashiconf-sg.id
}

resource "azurerm_network_interface_security_group_association" "bigip-ext-nsg" {
  network_interface_id      = azurerm_network_interface.bigip-ext-nic.id
  network_security_group_id = azurerm_network_security_group.f5-hashiconf-sg.id
}

# Setup Onboarding scripts
data "template_file" "vm_onboard" {
  template = file("${path.module}/onboard.tpl")

  vars = {
    admin_user     = var.uname
    admin_password = var.upassword
    DO_URL         = var.DO_URL
    AS3_URL        = var.AS3_URL
    TS_URL         = var.TS_URL
    libs_dir       = var.libs_dir
    onboard_log    = var.onboard_log
  }
}

data "template_file" "bigip_do_json" {
  template = file("${path.module}/do.json")

  vars = {
    regKey         = var.license1
    host1          = var.host1_name
    local_host     = var.host1_name
    local_selfip   = var.f5bigipext
    gateway        = var.data_gw
    dns_server     = var.dns_server
    ntp_server     = var.ntp_server
    timezone       = var.timezone
    admin_user     = var.uname
    admin_password = var.upassword
  }
}

data "template_file" "as3_json" {
  template = file("${path.module}/as3.json")

  vars = {
    rg_name         = azurerm_resource_group.f5-hashiconf-rg2.name
    subscription_id = var.sp_subscription_id
    tenant_id       = var.sp_tenant_id
    client_id       = var.sp_client_id
    client_secret   = var.sp_client_secret
    publicvip       = var.f5publicvip
    privatevip      = var.f5privatevip
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

# Create F5 BIG-IP VMs
resource "azurerm_linux_virtual_machine" "f5bigip" {
  name                            = "${var.prefix}-f5bigip"
  location                        = azurerm_resource_group.f5-hashiconf-rg2.location
  resource_group_name             = azurerm_resource_group.f5-hashiconf-rg2.name
  network_interface_ids           = [azurerm_network_interface.bigip-mgmt-nic.id, azurerm_network_interface.bigip-ext-nic.id]
  size                            = var.instance_type
  admin_username                  = var.uname
  admin_password                  = var.upassword
  disable_password_authentication = false
  computer_name                   = "${var.prefix}bigip"
  custom_data                     = base64encode(data.template_file.vm_onboard.rendered)

  os_disk {
    name                 = "${var.prefix}bigip-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "f5-networks"
    offer     = var.product
    sku       = var.image_name
    version   = var.bigip_version
  }

  plan {
    name      = var.image_name
    publisher = "f5-networks"
    product   = var.product
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mystorage.primary_blob_endpoint
  }

  tags = {
    Name        = "${var.environment}-f5bigip"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
  }
}

# Run Startup Script
resource "azurerm_virtual_machine_extension" "f5bigip-run-startup-cmd" {
  name                 = "${var.environment}-f5bigip-run-startup-cmd"
  virtual_machine_id   = azurerm_linux_virtual_machine.f5bigip.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "commandToExecute": "bash /var/lib/waagent/CustomData; exit 0;"
    }
  SETTINGS

  tags = {
    Name        = "${var.environment}-f5bigip-startup-cmd"
    environment = var.environment
    owner       = var.owner
    group       = var.group
    costcenter  = var.costcenter
    application = var.application
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
  depends_on = [azurerm_virtual_machine_extension.f5bigip-run-startup-cmd]
  # Running DO REST API
  provisioner "local-exec" {
    command = <<-EOF
      #!/bin/bash
      curl -k -X ${var.rest_do_method} https://${azurerm_public_ip.bigipmgmtpip.ip_address}${var.rest_do_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_bigip_do_file}
      x=1; while [ $x -le 60 ]; do STATUS=$(curl -s -k -X GET https://${azurerm_public_ip.bigipmgmtpip.ip_address}/mgmt/shared/declarative-onboarding/task -u ${var.uname}:${var.upassword}); if ( echo $STATUS | grep "OK" ); then break; fi; sleep 10; x=$(( $x + 1 )); done
      sleep 10
    EOF
  }
} 

resource "null_resource" "f5bigip_TS" {
  depends_on = [null_resource.f5bigip_DO]
  # Running TS REST API
  provisioner "local-exec" {
    command = <<-EOF
      #!/bin/bash
      curl -H 'Content-Type: application/json' -k -X POST https://${azurerm_public_ip.bigipmgmtpip.ip_address}${var.rest_ts_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm_ts_file}
    EOF
  }
}

resource "null_resource" "f5bigip_AS3" {
  depends_on = [null_resource.f5bigip_TS]
  # Running AS3 REST API
  provisioner "local-exec" {
    command = <<-EOF
      #!/bin/bash
      curl -k -X ${var.rest_as3_method} https://${azurerm_public_ip.bigipmgmtpip.ip_address}${var.rest_as3_uri} -u ${var.uname}:${var.upassword} -d @${var.rest_vm_as3_file}
    EOF
  }
}