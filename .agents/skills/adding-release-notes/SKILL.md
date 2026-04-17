---
name: adding-release-notes
description: Adds user-facing change descriptions to DevTools release notes. Use when documenting improvements, fixes, or new features in the NEXT_RELEASE_NOTES.md file.
---

# Adding Release Notes

This skill helps automate adding release notes to `packages/devtools_app/release_notes/NEXT_RELEASE_NOTES.md`.

## Workflow
Copy this checklist into your response to track progress:

```markdown
Release Notes Progress:
- [ ] Step 1: Formulate the entry (past tense)
- [ ] Step 2: Find the PR number (if not already known)
- [ ] Step 3: Determine the section (Inspector, Memory, etc.)
- [ ] Step 4: Add the entry (use scripts/add_note.dart)
- [ ] Step 5: Add images (if applicable)
```

## Guidelines

### 1. Identify the PR Number
If the PR number is unknown, use the following methods to find it:
- **Local Branch**: Identify the branch name using `git branch` or `git log`. If the branch is pushed to origin, it often has a linked PR.
- **GitHub CLI (`gh`)**: Use the GitHub CLI to find the PR associated with the current branch.
  - **IMPORTANT**: Always use `PAGER=cat` to prevent `gh` from hanging in non-interactive terminals.
  - Command: `PAGER=cat gh pr list --head <branch_name> --json number,title`
- **Search by Change Description**: Search open PRs using keywords from your change title or description.
  - Command: `PAGER=cat gh pr list --search "<keywords>" --limit 5`
- **Web Search**: If CLI tools fail, use `search_web` to find the PR on GitHub:
  - Query: `site:github.com/flutter/devtools "Add support for searching within the log details view"`

### 2. Formulate the Entry
- **Tense**: Always use **past tense** (e.g., "Added", "Improved", "Fixed").
- **Punctuation**: Always end entries with a **period**.
- **Template**: `* <Description>. [#<PR_NUMBER>](https://github.com/flutter/devtools/pull/<PR_NUMBER>)`
- **Placeholder**: Use `TODO` if you have exhausted all search methods and the PR has not been created yet.
- **Images**: If adding an image, indent it by two spaces to align with the bullet point, and ensure there is only one newline between the text and the image.
  - Correct Format:
    ```markdown
    - Added support for XYZ. [#TODO](https://github.com/flutter/devtools/pull/TODO)
      ![](images/my_feature.png)
    ```
- **Examples**:
  - `* Added support for XYZ. [#12345](https://github.com/flutter/devtools/pull/12345)`
  - `* Fixed a crash in the ABC screen. [#67890](https://github.com/flutter/devtools/pull/67890)`

### 3. User-Facing Changes Only
- **Criteria**: Focus on **what** changed for the user, not **how** it was implemented.
- **Avoid**: Technical details like "Implemented XYZ with a new controller", "Updated the build method", or naming internal classes.
- **Example (Bad)**: `* Implemented log details search using SearchControllerMixin. [#TODO](https://github.com/flutter/devtools/pull/TODO)`
- **Example (Good)**: `* Added search support to the log details view. [#TODO](https://github.com/flutter/devtools/pull/TODO)`

### 4. Determine Section
Match the change to the section in `NEXT_RELEASE_NOTES.md`:
- `General updates`
- `Inspector updates`
- `Performance updates`
- `CPU profiler updates`
- `Memory updates`
- `Debugger updates`
- `Network profiler updates`
- `Logging updates`
- `App size tool updates`
- `Deep links tool updates`
- `VS Code sidebar updates`
- `DevTools extension updates`
- `Advanced developer mode updates`

### 5. Add to NEXT_RELEASE_NOTES.md
Use the provided utility script to insert the note safely. The script handles replacing the TODO placeholder if it's the first entry in that section.

```bash
dart .agents/skills/adding-release-notes/scripts/add_note.dart "Inspector updates" "Added XYZ support" TODO
```

### 6. Optional: Images
Add images to `packages/devtools_app/release_notes/images/` and reference them:
```markdown
![Accessible description](images/screenshot.png "Hover description")
```
**Constraint**: Use **dark mode** for screenshots.

## Resources
- [README.md](../../../packages/devtools_app/release_notes/README.md): Official project guidance.
