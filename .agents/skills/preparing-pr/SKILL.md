---
name: preparing-pr
description: Prepare a pull request by running presubmit with fixes. Use when preparing to commit or send a PR.
---

# Preparing a Pull Request

Follow these steps to prepare a pull request for DevTools:

1.  **Verify `dt` configuration**:
    -   Ensure `dt` is available on the path by running `dt --help` or verifying its alias.
    -   If not available, refer to the [CONTRIBUTING guide](file:///Users/kenzieschmoll/develop/devtools/CONTRIBUTING.md#L64-L80) for instructions on how to set up the `dt` executable on your path.
2.  **Update Flutter SDK**:
    -   Run `dt update-flutter-sdk` to ensure the SDK is up to date.
3.  **Run Presubmit with Fixes**:
    -   Run `dt presubmit --fix` to address automated fixes.
    -   If any issues remain or if the command fails, fix the issues manually and run `dt presubmit --fix` again to verify the fix.
4.  **Run Tests for Affected Code**:
    -   Use `git status` or `git diff upstream/master` to find changed files.
    -   Run tests that are associated with the changed code. For example, if you edited `packages/devtools_app/lib/src/screens/logging/logging_screen.dart`, run the logging tests under `packages/devtools_app/test/screens/logging/`.

## Verification

If any step fails, stop and address the issue, and then verify the issue is fixed before proceeding.

> [!IMPORTANT]
> Do NOT commit or push changes without getting explicit user approval first.
