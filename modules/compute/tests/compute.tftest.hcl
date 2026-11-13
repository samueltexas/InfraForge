mock_provider "azurerm" {}

run "creates_private_linux_virtual_machine" {
  command = plan

  variables {
    vm_name              = "vm-infraforge-test"
    location             = "westeurope"
    resource_group_name  = "rg-infraforge-test"
    subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/application"
    managed_identity_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
    admin_username       = "infraadmin"
    admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK/zlrKdkXDa3zYMDdwzBQZR6OgoTnwaTZOIJPaRsLD3 infraforge-terraform-test"
    vm_size              = "Standard_B2s"
    os_disk_size_gb      = 64

    tags = {
      project     = "InfraForge"
      environment = "test"
      managed_by  = "terraform"
    }
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.name == "vm-infraforge-test"
    )
    error_message = "Unexpected virtual machine name."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.disable_password_authentication == true
    )
    error_message = "Password authentication must be disabled."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.secure_boot_enabled == true
    )
    error_message = "Secure Boot must be enabled."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.vtpm_enabled == true
    )
    error_message = "vTPM must be enabled."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.identity[0].type == "UserAssigned"
    )
    error_message = "The VM must use a user-assigned managed identity."
  }

  assert {
    condition = (
      azurerm_network_interface.this.ip_configuration[0].subnet_id ==
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/application"
    )
    error_message = "The VM must use the existing application subnet."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.source_image_reference[0].sku == "server"
    )
    error_message = "Unexpected Ubuntu image SKU."
  }
}

run "rejects_invalid_vm_name" {
  command = plan

  variables {
    vm_name              = "invalid/vm/name"
    location             = "westeurope"
    resource_group_name  = "rg-infraforge-test"
    subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/application"
    managed_identity_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
    admin_username       = "infraadmin"
    admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK/zlrKdkXDa3zYMDdwzBQZR6OgoTnwaTZOIJPaRsLD3 infraforge-terraform-test"
  }

  expect_failures = [var.vm_name]
}

run "rejects_root_administrator" {
  command = plan

  variables {
    vm_name              = "vm-infraforge-test"
    location             = "westeurope"
    resource_group_name  = "rg-infraforge-test"
    subnet_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/application"
    managed_identity_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
    admin_username       = "root"
    admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK/zlrKdkXDa3zYMDdwzBQZR6OgoTnwaTZOIJPaRsLD3 infraforge-terraform-test"
  }

  expect_failures = [var.admin_username]
}
