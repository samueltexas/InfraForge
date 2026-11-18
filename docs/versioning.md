# Module versioning and upgrades

Author: Samuel Texa

## Published contract

The repository already publishes [v1.0.0](https://github.com/samueltexas/InfraForge/releases/tag/v1.0.0).
Tags are immutable. Never move an existing tag to newer deployment code.
Every module shares the repository version; the module subdirectory appears
before the `?ref=` query in a Terraform Git source:

```hcl
module "storage" {
  source = "git::https://github.com/samueltexas/InfraForge.git//modules/storage?ref=v1.0.0"
  # Supply the required inputs from that release's variables.tf.
}
```

This is a source-address illustration, not a complete runnable configuration.
For stronger immutability, pin the full reviewed commit SHA. Terraform's provider
lock file locks providers, not Git module versions. Do not use `ref=main` for a
stable consumer deployment.

## Semantic Versioning policy

- PATCH: compatible bug fixes and documentation.
- MINOR: backward-compatible optional inputs/outputs and capabilities.
- MAJOR: removed/renamed inputs or outputs, incompatible defaults, state ownership
  changes, or behavior that requires consumer migration.

See [CHANGELOG](../CHANGELOG.md). The current unreleased changes require a major
release; they must not be relabeled as a compatible `v1.0.1` or `v1.1.0`.

## Release checklist

1. Review the public input/output contract and the plan effects for existing callers.
2. Document breaking changes and concrete upgrade steps in CHANGELOG.
3. Require green CI on the exact release commit and validate upgrade plans on a
   representative state copy. Never apply an upgrade solely because tests pass.
4. Create an annotated SemVer tag on that commit and push it; publish GitHub release
   notes linked to the changelog. Never overwrite a released tag.
5. Verify `//modules/<name>?ref=<tag>` resolves to the intended source.

The next major release is intentionally not published before its upgrade behavior
is validated. The live demonstration and the published reusable release are distinct.
