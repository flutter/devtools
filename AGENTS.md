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

### Code Quality & Maintainability
-   **Single Responsibility**: Methods should ideally be 10-20 lines. If a method exceeds 30 lines, suggest a refactor.
-   **DRY (Don't Repeat Yourself)**: Identify blocks of code that are 90%+ identical to existing utility methods in this repo and flag them for duplication.
-   **Meaningful Naming**: Variables should describe their intent (e.g., `timeoutInMs` instead of `t`).
-   **Descriptive Pull Request**: Contributors should include the information recommended in the pull request template (In `.github/PULL_REQUEST_TEMPLATE.md`).

## Documentation
- All public members should have documentation.
- **Answer your own questions**: If you have a question, find the answer, and then document it where you first looked.
- **Documentation should be useful**: Explain the *why* and the *how*.
- **Introduce terms**: Assume the reader does not know everything. Link to definitions.
- Use `///` for public-quality documentation, even on private members.

## Running Tests
-   **Standard Packages**: Run unit and widget tests with `flutter test`.
-   **`packages/devtools_shared`**: Run tests with `dart test`.
-   **Integration Tests**: Refer to the [Integration Test README](packages/devtools_app/integration_test/README.md) for instructions on running integration tests.

## UI Development Guidelines

### Constants and Magic Values
-   **Avoid Raw Values**: Avoid using raw strings or numbers in UI code. Use named constants instead.

### Themes and Styles
-   **Use Existing Themes**: Use existing theme values and text styles from `packages/devtools_app_shared/lib/src/ui/theme/theme.dart` (e.g., `Theme.of(context).regularTextStyle`).
-   **Reuse Patterns**: Reuse common patterns and styles used in other UI code in the repository.

### Code Reuse
-   **Use Shared Components & Utils**: Prefer using reusable components from `shared/ui/` (such as `packages/devtools_app/lib/src/shared/ui/common_widgets.dart`), primitives from `shared/primitives/`, and utilities from `shared/utils/` rather than creating things from scratch.

### Helper Widgets and Methods
-   **Avoid Long Build Methods**: Use separate helper widgets instead of writing excessively long build methods to keep the structure clear.
-   **Prefer Widgets Over Methods**: Create small, composable helper widgets rather than helper methods that return a widget at build time. This improves readability and allows Flutter to optimize tree updates better.
