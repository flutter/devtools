---
name: reviewing-devtools-prs
description: DevTools repository-specific PR review workflow enforcing DevTools style guidelines and common review patterns. Use when reviewing pull requests in the flutter/devtools repository.
---

# Reviewing DevTools Pull Requests

Extends [reviewing-prs](../reviewing-prs/SKILL.md) for pull requests in `flutter/devtools`. Follow [reviewing-prs](../reviewing-prs/SKILL.md) for GitHub CLI data retrieval and the strict user approval workflow.

## References & Style Guidelines

Read and enforce:
- **Style Guide**: [styleguide.md](../../.gemini/styleguide.md) (severity tags `[MUST-FIX]`, `[CONCERN]`, `[NIT]`, zero-formatting policy, copyright headers, DRY rules, magic values)
- **Repository Constraints**: [AGENTS.md](../../AGENTS.md)
- **Code Style**: [STYLE.md](../../STYLE.md)

## Common Review Patterns

1. **Listener & Resource Disposals**:
   - Ensure controller and notifier listeners use `addAutoDisposeListener(...)`.

2. **Helper Widgets over Helper Methods**:
   - Prefer small composable `Widget` classes over helper methods returning `Widget` (`_buildFoo()`).

3. **Reuse Shared Components & Test Helpers**:
   - Use standard shared widgets (e.g. `CenteredMessage`) and test mocks (e.g. `mockConnectedApp`) instead of re-creating them inline.

4. **TODO Formatting**:
   - Link TODOs to a GitHub issue or LDAP: `// TODO(https://github.com/flutter/devtools/issues/<issue_number>): <description>`.

5. **Async & Unawaited Futures**:
   - Audit unawaited futures and suggest `unawaited(...)` or `safeUnawaited(...)` where appropriate.

6. **Feature Flags**:
   - Default feature flags to `false` with explicit test expectations in `feature_flags_test.dart`.

7. **Test File Structure & PR Scope**:
   - Place test fakes/helpers below `main()`.
   - Ask authors to revert unrelated file changes or commented-out test code.

8. **Constant Scoping**:
   - Keep single-use constants local to the component, but extract user-facing UI strings into shared constants when used across multiple places.

9. **Release Notes Scope (`NEXT_RELEASE_NOTES.md`)**:
   - Release notes are strictly for end-user facing changes (e.g. Inspector, Memory UI/UX). Internal tools (`dt` / `devtools_tool`), CI, and refactors are NOT user-facing.
   - Request removing release notes added for developer tools like `dt`, or suggest a `* <Description>. [#<PR_NUMBER>](https://github.com/flutter/devtools/pull/<PR_NUMBER>)` entry via [adding-release-notes](../adding-release-notes/SKILL.md) if a user-facing PR lacks one.
