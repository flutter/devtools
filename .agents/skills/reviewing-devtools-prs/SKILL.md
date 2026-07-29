---
name: reviewing-devtools-prs
description: DevTools repository-specific PR review workflow enforcing DevTools style guidelines and repository rules. Use when reviewing pull requests in the flutter/devtools repository.
---

# Reviewing DevTools Pull Requests

Extends [reviewing-prs](../reviewing-prs/SKILL.md) with repository-specific rules for `flutter/devtools`.

## References & Guidelines

Always inspect and adhere to:
- **Style Guide**: [styleguide.md](../../.gemini/styleguide.md) (severity tags `[MUST-FIX]`, `[CONCERN]`, `[NIT]`, zero-formatting policy, copyright headers, DRY rules, named constants)
- **Repository Constraints**: [AGENTS.md](../../AGENTS.md)
- **Code Style**: [STYLE.md](../../STYLE.md)

## DevTools Specific Rules

### 1. Release Notes Scope (`NEXT_RELEASE_NOTES.md`)

- Release notes are **strictly for end-user facing changes** in DevTools (e.g. Inspector, Memory, Debugger UI/UX).
- Internal developer tools (e.g., `dt` / `devtools_tool`), CI, build scripts, and internal refactors are **NOT user-facing**.
- **Incorrect Release Note**: If a PR adds a release note for a non-user-facing tool (like `dt`), request removing the release note entry.
- **Missing Release Note**: If a PR has user-facing changes but lacks release notes, consult [adding-release-notes](../adding-release-notes/SKILL.md) and suggest a `* <Description>. [#<PR_NUMBER>](https://github.com/flutter/devtools/pull/<PR_NUMBER>)` entry under the appropriate section.

### 2. Review Protocol

- Apply the workflow in [reviewing-prs](../reviewing-prs/SKILL.md) for information gathering, comment drafting, and user approval.
- Prefix actionable inline feedback with severity tags (`[MUST-FIX]`, `[CONCERN]`, `[NIT]`) per [styleguide.md](../../.gemini/styleguide.md).
