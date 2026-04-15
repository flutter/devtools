# DevTools Repo Guidelines for AI Assistants

Follow these rules when working in this repository.

## Repository Rules

### Dependencies
-   **`packages/devtools_shared`**: Never introduce a Flutter dependency or a dependency on web-only Dart libraries.
-   **Imports**: Never import `packages/devtools_app/lib/devtools_app.dart` in code under `packages/devtools_app/lib/src/`. It is acceptable in test code.

### Published Packages (`packages/devtools_shared`, `packages/devtools_app_shared`, `packages/devtools_extensions`)
- Document file changes in the respective `CHANGELOG.md` files.
- Ensure version numbers in `pubspec.yaml` are updated accordingly for required changes.
- Ensure no breaking changes are introduced. If introduced, they must be intentional and documented.
- The published packages should not depend on unpublished packages like `packages/devtools_app` and `packages/devtools_test`.

### Code Style
-   **Style Guide**: Follow the DevTools style guide in [STYLE.md](STYLE.md).
-   **Formatting & Analysis**: Always ensure code is formatted properly and has no analysis errors or warnings before completing a task.

## Running Tests

-   **Standard Packages**: Run unit and widget tests with `flutter test`.
-   **`packages/devtools_shared`**: Run tests with `dart test`.
-   **Integration Tests**: Refer to the [Integration Test README](packages/devtools_app/integration_test/README.md) for instructions on running integration tests.

## Tooling Best Practices

-   **MCP Tools**: Prefer using MCP server tools over shell commands whenever possible.

## UI Development Guidelines

### Constants and Magic Values
-   **Avoid Raw Values**: Avoid using raw strings or numbers in UI code. Use named constants instead.

### Themes and Styles
-   **Use Existing Themes**: Use existing theme values and text styles from `packages/devtools_app_shared/lib/src/ui/theme/theme.dart` (e.g., `Theme.of(context).regularTextStyle`).
-   **Reuse Patterns**: Reuse common patterns and styles used in other UI code in the repository.

### Code Reuse
-   **Use Shared Components & Utils**: Prefer using reusable components from `shared/ui/` (such as `packages/devtools_app/lib/src/shared/ui/common_widgets.dart`), primitives from `shared/primitives/`, and utilities from `shared/utils/` rather than creating things from scratch.

