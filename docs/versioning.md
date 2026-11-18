# Module versioning and upgrades

Author: Samuel Texa

## Published contract

The current release is [v2.0.0](https://github.com/samueltexas/InfraForge/releases/tag/v2.0.0).
The original v1.0.0 release remains available and unchanged.
Tags are immutable. Never move an existing tag to newer deployment code.
Every module shares the repository version; the module subdirectory appears
before the `?ref=` query in a Terraform Git source:

```hcl
module "storage" {
  source = "git::https://github.com/samueltexas/InfraForge.git//modules/storage?ref=v2.0.0"
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

See [CHANGELOG](../CHANGELOG.md). Version 2.0.0 includes incompatible defaults
and state-ownership changes; it is not a compatible 1.x update.
Future compatible features use 2.1.0, 2.2.0; compatible fixes use 2.0.1.

## Release checklist

1. Review the public input/output contract and the plan effects for existing callers.
2. Document breaking changes and concrete upgrade steps in CHANGELOG.
3. Require green CI on the exact release commit and validate upgrade plans on a
   representative state copy. Never apply an upgrade solely because tests pass.
4. Create an annotated SemVer tag on that commit and push it; publish GitHub release
   notes linked to the changelog. Never overwrite a released tag.
5. Verify `//modules/<name>?ref=<tag>` resolves to the intended source.

Release 2.0.0 is validated by module plan tests, CI and a no-change plan against
the existing v2 demonstration deployment. Migration of an arbitrary v1 Azure state
is not claimed as tested: consumers must review the breaking changes and validate
their own upgrade plan, especially when changing resource ownership.
