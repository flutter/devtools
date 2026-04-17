---
name: adding-changelog-entries
description: Guides the creation of changelog entries for published packages in the DevTools repository. Use when documenting changes in CHANGELOG.md files for devtools_shared, devtools_app_shared, or devtools_extensions.
---

# Adding Changelog Entries

When adding changelog entries to published packages (`devtools_shared`, `devtools_app_shared`, and `devtools_extensions`), follow these rules:

- **Check Publication State**: Never add an entry to an already published version (e.g. `# 12.1.0`). You MUST check which versions are published on pub.dev (e.g., at `https://pub.dev/packages/<package_name>/versions`) before determining section headers! If a version is not yet published, it should be suffixed with the next numeric `-wip` tag (e.g., `## 0.5.1-wip`) rather than generic placeholder headers like `# WIP`!
- **New Version Headers**: If a version bump is required, you MUST first use the instructions in [updating-package-versions](../updating-package-versions/SKILL.md) to update the package version in `pubspec.yaml`, and then add a new header to the changelog file with the new version (e.g., `## 0.5.1-wip`) before adding your entries.
- **Accurately Distinguish Packages**: Ensure that the cleanups or edits applied to a specific package's changelog entries belong strictly to that package path (e.g., changes in `devtools_app` do not warrant entries in `devtools_shared`).
- **Conciseness and Accuracy**: Describe clearly what was changed and why. Avoid generic descriptions without context, such as "Fixes missing deprecation message". Indicate specifically what was added or removed.
