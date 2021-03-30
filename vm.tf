//Create a resource group
resource "azurerm_resource_group" "tfdemorg" {
  name     = "tfdemorg"
  location = var.location
}

//Association the network sec group with subnet



//Create

resource "tls_private_key" "tfprivatekey_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

output "tls_private_key" {
  value = tls_private_key.tfprivatekey_ssh.private_key_pem

}


//Create the VM

resource "azurerm_linux_virtual_machine" "tfmyvm" {
  name                = "tfmyvm"
  resource_group_name = azurerm_resource_group.tfdemorg.name
  location            = azurerm_resource_group.tfdemorg.location
  size                = "Standard_B1ls"
  admin_username      = "adminuser"

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

//Spit the key to a file with the specific permissions
resource "local_file" "private_key" {
  content         = tls_private_key.tfprivatekey_ssh.private_key_pem
  filename        = "key"
  file_permission = "600"
}

resource "null_resource" "upload_config_db" {

  provisioner "file" {

    connection {
      type        = "ssh"
      user        = "adminuser"
      host        = azurerm_public_ip.tfmyip.ip_address
      private_key = tls_private_key.tfprivatekey_ssh.private_key_pem #file("./key")
    }

    source      = "mysqld.cnf"
    destination = "/home/adminuser/mysqld.cnf"
  }
  depends_on = [
    local_file.private_key,
    azurerm_linux_virtual_machine.tfmyvm
  ]
}

resource "null_resource" "remote_exec_vm2" {

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = "adminuser"
      host        = azurerm_public_ip.tfmyip.ip_address
      private_key = tls_private_key.tfprivatekey_ssh.private_key_pem #file("./key")
    }

    inline = [
      "sudo apt update",
      # "echo \"mysql-server-5.7 mysql-server/root_password password root\" | sudo debconf-set-selections",
      # "echo \"mysql-server-5.7 mysql-server/root_password_again password root\" | sudo debconf-set-selections",
      "sudo apt install -y mariadb-server",
      "sudo cat /home/adminuser/mysqld.cnf > /etc/mysql/mariadb.conf.d/mysqld.cnf",
      "sudo service mysql restart"
    ]
  }

  depends_on = [
    null_resource.upload_config_db
  ]

}
