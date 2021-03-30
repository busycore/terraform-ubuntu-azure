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

resource "azurerm_linux_virtual_machine" "tfmyvm" {
  name                = "tfmyvm"
  resource_group_name = azurerm_resource_group.tfdemorg.name
  location            = azurerm_resource_group.tfdemorg.location
  #size                = "Standard_B1ls"
  size           = "Standard_DS1_v2"
  admin_username = "adminuser"

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
    sku       = "18.04-LTS"
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

resource "time_sleep" "wait_30_seconds_db" {
  depends_on      = [azurerm_linux_virtual_machine.tfmyvm]
  create_duration = "30s"
}

resource "null_resource" "upload_config_sql" {

  provisioner "file" {

    connection {
      type        = "ssh"
      user        = "adminuser"
      host        = azurerm_public_ip.tfmyip.ip_address
      private_key = tls_private_key.tfprivatekey_ssh.private_key_pem #file("./key")
    }
    source      = "mysql"
    destination = "/home/adminuser"
  }
  depends_on = [
    local_file.private_key,
    azurerm_linux_virtual_machine.tfmyvm,
    time_sleep.wait_30_seconds_db
  ]
}

resource "null_resource" "remote_exec_vm" {

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = "adminuser"
      host        = azurerm_public_ip.tfmyip.ip_address
      private_key = tls_private_key.tfprivatekey_ssh.private_key_pem #file("./key")
    }

    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y mysql-server-5.7",
      "sudo mysql < /home/adminuser/mysql/script/user.sql",
      "sudo mysql < /home/adminuser/mysql/script/schema.sql",
      "sudo mysql < /home/adminuser/mysql/script/data.sql",
      "sudo cp -f /home/adminuser/mysql/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
      "sudo service mysql restart",
      "sleep 20",
    ]

  }

  depends_on = [
    null_resource.upload_config_sql,
    time_sleep.wait_30_seconds_db,
  ]

}
