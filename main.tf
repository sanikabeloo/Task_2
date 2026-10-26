
# Public IP for Linux Bastion Host VM
resource "azurerm_public_ip" "host_ip" {
  name                = "${var.project_name}-host-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Public IP for managed Azure Bastion Service
resource "azurerm_public_ip" "bastion_service_ip" {
  name                = "${var.project_name}-bastion-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NSG for Linux Bastion Host VM
resource "azurerm_network_security_group" "host_nsg" {
  name                = "${var.project_name}-host-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH-From-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip_cidr
    destination_address_prefix = "*"
  }
}

# NSG for Web Tier VM
resource "azurerm_network_security_group" "web_nsg" {
  name                = "${var.project_name}-web-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # SSH from Linux Bastion Host subnet
  security_rule {
    name                       = "Allow-SSH-From-Host"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # SSH from Azure Bastion Service subnet
  security_rule {
    name                       = "Allow-SSH-From-Azure-Bastion"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/26"
    destination_address_prefix = "*"
  }

  # HTTP access to Web VM
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG for App Tier
resource "azurerm_network_security_group" "app_nsg" {
  name                = "${var.project_name}-app-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-App-From-Web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }
}

# NSG for DB Tier
resource "azurerm_network_security_group" "db_nsg" {
  name                = "${var.project_name}-db-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-DB-From-App"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "10.0.3.0/24"
    destination_address_prefix = "*"
  }
}

# NSG Associations
resource "azurerm_subnet_network_security_group_association" "host" {
  subnet_id                 = azurerm_subnet.bastion_host.id
  network_security_group_id = azurerm_network_security_group.host_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

# NIC for Linux Bastion Host VM
resource "azurerm_network_interface" "host_nic" {
  name                = "${var.project_name}-host-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.bastion_host.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.host_ip.id
  }
}

# NIC for Web VM - private IP only
resource "azurerm_network_interface" "web_nic" {
  name                = "${var.project_name}-web-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Linux Bastion Host VM
resource "azurerm_linux_virtual_machine" "host" {
  name                            = "${var.project_name}-bastion-vm"
  computer_name                   = "bastionvm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = "azureuser"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.host_nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.host
  ]
}

# Web Linux VM - no public IP
resource "azurerm_linux_virtual_machine" "web" {
  name                            = "${var.project_name}-web-vm"
  computer_name                   = "webvm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = var.vm_size
  admin_username                  = "azureuser"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.web_nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.web
  ]
}

# Managed Azure Bastion Service
resource "azurerm_bastion_host" "bastion_service" {
  name                = "${var.project_name}-bastion-service"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"


  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.azure_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion_service_ip.id
  }
}