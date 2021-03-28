terraform {
  required_version = ">=0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.26"
    }
  }
}

//The provider for azure cloud
//skip registration once we are already logged in our session
provider "azurerm" {
  skip_provider_registration = true
  features {}
}

//Create a resource group
resource "azurerm_resource_group" "tfdemorg" {
  name     = "tfdemorg"
  location = "East US"
}

//Create a virtual network
resource "azurerm_virtual_network" "tfmynetwork" {
  name                = "tfmynetwork"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.tfdemorg.location
  resource_group_name = azurerm_resource_group.tfdemorg.name
}

//Create a subnet
resource "azurerm_subnet" "tfmysubnet" {
  name                 = "tfmysubnet"
  resource_group_name  = azurerm_resource_group.tfdemorg.name
  virtual_network_name = azurerm_virtual_network.tfmynetwork.name
  address_prefixes     = ["10.0.2.0/24"]
}

//Create public IP
resource "azurerm_public_ip" "tfmyip" {
  name                = "tfmyip"
  resource_group_name = azurerm_resource_group.tfdemorg.name
  location            = azurerm_resource_group.tfdemorg.location
  allocation_method   = "Static"

  tags = {
    environment = "MBA_test"
  }
}

//Open firewall to access via public ip

resource "azurerm_network_security_group" "tfmysg" {
  name                = "tfmysg"
  location            = azurerm_resource_group.tfdemorg.location
  resource_group_name = azurerm_resource_group.tfdemorg.name

  security_rule {
    name                       = "SSH_ACCESS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "MBA_test"
  }
}

//Create a network interface
resource "azurerm_network_interface" "tfmynic" {
  name                = "tfmynic"
  location            = azurerm_resource_group.tfdemorg.location
  resource_group_name = azurerm_resource_group.tfdemorg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tfmysubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tfmyip.id
  }
}


//Association the network sec group with subnet

resource "azurerm_subnet_network_security_group_association" "tfmynetsecas" {
  subnet_id                 = azurerm_subnet.tfmysubnet.id
  network_security_group_id = azurerm_network_security_group.tfmysg.id
}


//Create

resource "tls_private_key" "tfprivatekey_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

output "tls_private_key" {
  value = tls_private_key.tfprivatekey_ssh.private_key_pem

}


//Availability set
# resource "azurerm_availability_set" "tfavset" {
#   name                         = "tfavset"
#   location                     = azurerm_resource_group.tfdemorg.location
#   resource_group_name          = azurerm_resource_group.tfdemorg.name
#   platform_fault_domain_count  = 2
#   platform_update_domain_count = 2
#   managed                      = true
# }

//Create the VM

resource "azurerm_linux_virtual_machine" "tfmyvm" {
  name                = "tfmyvm"
  resource_group_name = azurerm_resource_group.tfdemorg.name
  location            = azurerm_resource_group.tfdemorg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  #platform_fault_domain = 0
  #zone = 0

  # priority        = "Spot"
  # eviction_policy = "Deallocate"

  network_interface_ids = [
    azurerm_network_interface.tfmynic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.tfprivatekey_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

output "public_ip_vm" {
  value = azurerm_public_ip.tfmyip.ip_address
}
