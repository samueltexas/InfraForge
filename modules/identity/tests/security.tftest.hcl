mock_provider "azurerm" {}

variables {
  name                = "id-infraforge-dev"
  location            = "westeurope"
  resource_group_name = "rg-infraforge-dev"
}

run "valid_read_only_assignment" {
  command = plan

  variables {
    role_assignments = {
      resource_reader = {
        scope     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Storage/storageAccounts/stinfraforgedev"
        role_name = "Reader"
      }
    }
  }
}

run "reject_owner_role" {
  command = plan

  variables {
    role_assignments = {
      admin = {
        scope     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-infraforge-dev/providers/Microsoft.Storage/storageAccounts/stinfraforgedev"
        role_name = "Owner"
      }
    }
  }

  expect_failures = [
    var.role_assignments
  ]
}

run "reject_subscription_scope" {
  command = plan

  variables {
    role_assignments = {
      reader = {
        scope     = "/subscriptions/00000000-0000-0000-0000-000000000000"
        role_name = "Reader"
      }
    }
  }

  expect_failures = [
    var.role_assignments
  ]
}
