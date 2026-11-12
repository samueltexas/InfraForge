"""Regression tests for InfraForge identity security controls."""

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VARIABLES = ROOT / "modules/identity/variables.tf"
MAIN = ROOT / "modules/identity/main.tf"
EXAMPLE = ROOT / "examples/identity/main.tf"


class IdentitySecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.variables = VARIABLES.read_text(encoding="utf-8")
        cls.main = MAIN.read_text(encoding="utf-8")
        cls.example = EXAMPLE.read_text(encoding="utf-8")

    def test_managed_identity_is_used(self):
        self.assertIn(
            'resource "azurerm_user_assigned_identity" "this"',
            self.main,
        )

    def test_role_assignments_reference_managed_identity(self):
        self.assertRegex(
            self.main,
            r"principal_id\s*=\s*"
            r"azurerm_user_assigned_identity\.this\.principal_id",
        )

    def test_role_assignment_uses_explicit_scope(self):
        self.assertRegex(
            self.main,
            r"scope\s*=\s*each\.value\.scope",
        )

    def test_role_assignment_uses_approved_role_input(self):
        self.assertRegex(
            self.main,
            r"role_definition_name\s*=\s*each\.value\.role_name",
        )

    def test_read_only_role_allowlist_exists(self):
        for role in (
            "Reader",
            "Monitoring Reader",
            "Storage Blob Data Reader",
        ):
            self.assertIn(f'"{role}"', self.variables)

    def test_administrative_roles_are_not_approved(self):
        allowlist_match = re.search(
            r"contains\(\s*\[(.*?)\]\s*,\s*assignment\.role_name",
            self.variables,
            re.DOTALL,
        )
        self.assertIsNotNone(
            allowlist_match,
            "Expected an explicit role allowlist.",
        )

        allowed_roles = re.findall(
            r'"([^"]+)"',
            allowlist_match.group(1),
        )

        for forbidden in (
            "Owner",
            "Contributor",
            "User Access Administrator",
            "Role Based Access Control Administrator",
        ):
            self.assertNotIn(forbidden, allowed_roles)

    def test_scope_requires_resource_level_path(self):
        self.assertIn(
            "assignment.scope",
            self.variables,
        )
        self.assertIn(
            "resourceGroups/",
            self.variables,
        )
        self.assertIn(
            "providers/",
            self.variables,
        )

    def test_example_uses_read_only_role(self):
        self.assertRegex(
            self.example,
            r'role_name\s*=\s*"Reader"',
        )

    def test_example_uses_placeholder_subscription(self):
        self.assertIn(
            "00000000-0000-0000-0000-000000000000",
            self.example,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
