# Create a private network interface in the application subnet.
resource "azurerm_network_interface" "this" {
  name                = "nic-${var.vm_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Deploy a hardened Ubuntu Linux virtual machine.
resource "azurerm_linux_virtual_machine" "this" {
  #checkov:skip=CKV_AZURE_50:This module does not declare or attach VM extensions. Extension resources are independently governed.
  name                = var.vm_name
  computer_name       = var.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.this.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  # Reuse the existing user-assigned managed identity.
  identity {
    type = "UserAssigned"

    identity_ids = [
      var.managed_identity_id
    ]
  }

  os_disk {
    name                 = "osdisk-${var.vm_name}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Enable Trusted Launch security features.
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Use Azure-managed storage for boot diagnostics.
  boot_diagnostics {}

  tags = var.tags
}
