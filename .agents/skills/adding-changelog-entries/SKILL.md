---
name: adding-changelog-entries
description: Guides the creation of changelog entries for published packages in the DevTools repository. Use when documenting changes in CHANGELOG.md files for devtools_shared, devtools_app_shared, or devtools_extensions.
---

# Adding Changelog Entries

When adding changelog entries to published packages (`devtools_shared`, `devtools_app_shared`, and `devtools_extensions`), follow these rules:

- **Check Publication State**: Never add an entry to an already published version (e.g. `# 12.1.0`). You MUST check which versions are published on pub.dev (e.g., at `https://pub.dev/packages/<package_name>/versions`) before determining section headers! If a version is not yet published, it should be suffixed with the next numeric `-wip` tag (e.g., `## 0.5.1-wip`) rather than generic placeholder headers like `# WIP`!
- **Lock-step Mono-repo Updates**: Between the published packages (`devtools_shared`, `devtools_app_shared`, and `devtools_extensions`), version bumps and dependency constraints modifications targeting each other MUST happen in lock-step to avoid graph resolution failures! Always update them together!
- **Match Pubspec Versions Exactly**: When updating dependency versions in published package `pubspec.yaml` files, ALWAYS use the *actual* version specified in the target package's `pubspec.yaml`. If a package version contains a suffix like `-wip` (e.g., `13.0.0-wip`), that full string MUST be used in dependency declarations (e.g., `devtools_shared: ^13.0.0-wip`). Leaving off the suffix will cause version solving failures.
- **Version Decisions**: Decide if it should be a major, minor, or patch version based on your edits:
  - **Breaking changes**: Major bump (+1 to first component, others reset to 0). E.g., removals of public constants, properties, getters/setters, or APIs.
  - **New features or deprecation start**: Minor bump (+1 to second component, patch resets to 0).
  - **Bug fixes and non-breaking changes**: Patch bump (+1 to third component).
- **Accurately Distinguish Packages**: Ensure that the cleanups or edits applied to a specific package's changelog entries belong strictly to that package path (e.g., changes in `devtools_app` do not warrant entries in `devtools_shared`).
- **Conciseness and Accuracy**: Describe clearly what was changed and why. Avoid generic descriptions without context, such as "Fixes missing deprecation message". Indicate specifically what was added or removed.
