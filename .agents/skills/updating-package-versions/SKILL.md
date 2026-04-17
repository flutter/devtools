---
name: updating-package-versions
description: Guides updating dependency versions in published packages to avoid mono-repo resolution failures.
---

# Updating Package Versions

When updating dependency versions in published package `pubspec.yaml` files (`devtools_shared`, `devtools_app_shared`, and `devtools_extensions`), follow these rules to protect the local mono-repo workspace graph:

- **Version Decisions**: Decide if it should be a major, minor, or patch version based on your edits:
  - **Breaking changes**: Major bump (+1 to first component, others reset to 0). E.g., removals of public constants, properties, getters/setters, or APIs.
  - **New features or deprecation start**: Minor bump (+1 to second component, patch resets to 0).
  - **Bug fixes and non-breaking changes**: Patch bump (+1 to third component).
- **Match Exact Versions**: Always use the **actual** version specified in the target package's `pubspec.yaml` file.
- **Suffix Preservation**: If a requested version contains a suffix like `-wip` (e.g., `13.0.0-wip`), the full string MUST be used in dependency constraints (e.g., `devtools_shared: ^13.0.0-wip`).
- **Prevent Graph Failures**: Do not drop the suffix or estimate the base version tags. Version solver operations will fail in the local workspace if dependencies point to published strings that can't be resolved in non-published repositories.
- **Resolution Testing**: After updating versions, run `flutter pub get` in the repository to ensure version solving is satisfied. If this returns errors, you should fix the errors and try again.
- **Updating devtools_app**: In `packages/devtools_app/pubspec.yaml`:
  - Dependencies on published packages do not have version constraints. This is intentional; do not change this when updating versions.
  - Always use the `dt update-version` tool to update the `devtools_app` version.
  - This should only be updated for monthly releases and cherry pick releases, so perform this update only when explicitly asked to.
