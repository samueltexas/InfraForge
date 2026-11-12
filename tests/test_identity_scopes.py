"""Validate IAM resource scope patterns from Terraform configuration."""

import re
import unittest
from pathlib import Path

import hcl2


ROOT = Path(__file__).resolve().parents[1]
VARIABLES = ROOT / "modules/identity/variables.tf"

SUBSCRIPTION = "00000000-0000-0000-0000-000000000000"
RESOURCE = (
    f"/subscriptions/{SUBSCRIPTION}"
    "/resourceGroups/rg-infraforge-dev"
    "/providers/Microsoft.Storage/storageAccounts/stinfraforgedev"
)


class IdentityScopeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with VARIABLES.open(encoding="utf-8") as source:
            document = hcl2.load(source)

        role_variable = next(
            item["role_assignments"]
            for item in document["variable"]
            if "role_assignments" in item
        )

        scope_validation = next(
            item["condition"]
            for item in role_variable["validation"]
            if "assignment.scope" in item["condition"]
        )

        match = re.search(r'regex\(\s*"([^"]+)"', scope_validation)
        if match is None:
            raise AssertionError("Terraform scope regex was not found.")

        cls.scope_pattern = re.compile(match.group(1))

    def test_resource_scope_is_accepted(self):
        self.assertIsNotNone(self.scope_pattern.fullmatch(RESOURCE))

    def test_nested_resource_scope_is_accepted(self):
        nested = RESOURCE + "/blobServices/default"
        self.assertIsNotNone(self.scope_pattern.fullmatch(nested))

    def test_subscription_scope_is_rejected(self):
        scope = f"/subscriptions/{SUBSCRIPTION}"
        self.assertIsNone(self.scope_pattern.fullmatch(scope))

    def test_resource_group_scope_is_rejected(self):
        scope = (
            f"/subscriptions/{SUBSCRIPTION}"
            "/resourceGroups/rg-infraforge-dev"
        )
        self.assertIsNone(self.scope_pattern.fullmatch(scope))

    def test_malformed_subscription_is_rejected(self):
        scope = RESOURCE.replace(SUBSCRIPTION, "not-a-valid-uuid")
        self.assertIsNone(self.scope_pattern.fullmatch(scope))

    def test_missing_resource_name_is_rejected(self):
        scope = RESOURCE.rsplit("/", 1)[0]
        self.assertIsNone(self.scope_pattern.fullmatch(scope))

    def test_scope_with_whitespace_is_rejected(self):
        self.assertIsNone(
            self.scope_pattern.fullmatch(RESOURCE + " invalid")
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
