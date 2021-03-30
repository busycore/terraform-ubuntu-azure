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


resource "azurerm_subnet_network_security_group_association" "tfmynetsecas" {
  subnet_id                 = azurerm_subnet.tfmysubnet.id
  network_security_group_id = azurerm_network_security_group.tfmysg.id
}
