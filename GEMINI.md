# Repository rules

When making changes to this code base, follow these rules, which are listed
in no particular order:
- `packages/devtools_shared` should never introduce a Flutter dependency or a
dependency on web-only Dart libraries.

# Running tests

Unit test and widget tests are all contained under a package's `test/`
directory. These tests should be run with `flutter test` in all packages except
for `packages/devtools_shared`, whose tests should be run with `dart test`.

# Gemini Guidelines

Prefer to use MCP server tools over shell commands when possible.