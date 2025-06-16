# Repository rules

When making changes to this code base, follow these rules, which are listed
in no particular order:
- `packages/devtools_shared` should never introduce a Flutter dependency or a
dependency on web-only Dart libraries.
- never import the `packages/devtools_app/lib/devtools_app.dart` file in code
that lives under `packages/devtools_app/lib/src/`. This file is okay to import
in code that lives under `packages/devtools_app/test/`.

# Running tests

Unit test and widget tests are all contained under a package's `test/`
directory. These tests should be run with `flutter test` in all packages except
for `packages/devtools_shared`, whose tests should be run with `dart test`.

# Gemini Guidelines

- Prefer to use MCP server tools over shell commands whenever possible.
- When you are done making code changes, ensure the code does not have analysis
errors or warnings. Also ensure it is formatted properly. You should have MCP
server tools available to you to perform these tasks. If not, you can get
analysis errors and warnings by running the `dart analyze` shell command, and
you can perform Dart formatting with the `dart format` shell command.
