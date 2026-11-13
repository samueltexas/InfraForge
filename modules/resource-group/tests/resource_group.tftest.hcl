mock_provider "azurerm" {}

run "creates_resource_group_with_expected_configuration" {
  command = plan

  variables {
    name     = "rg-infraforge-test"
    location = "westeurope"

    tags = {
      project     = "InfraForge"
      environment = "test"
      managed_by  = "terraform"
    }
  }

  assert {
    condition     = azurerm_resource_group.this.name == "rg-infraforge-test"
    error_message = "Unexpected Resource Group name."
  }

  assert {
    condition     = azurerm_resource_group.this.location == "westeurope"
    error_message = "Unexpected Resource Group location."
  }

  assert {
    condition     = azurerm_resource_group.this.tags["project"] == "InfraForge"
    error_message = "Project tag was not applied."
  }
}

run "rejects_invalid_resource_group_name" {
  command = plan

  variables {
    name     = "invalid/resource-group"
    location = "westeurope"
  }

  expect_failures = [var.name]
}
