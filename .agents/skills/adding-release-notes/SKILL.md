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
- [ ] Step 1: Formulate the entry (past tense, PR link)
- [ ] Step 2: Determine the section (Inspector, Memory, etc.)
- [ ] Step 3: Add the entry (use scripts/add_note.py)
- [ ] Step 4: Add images (if applicable)
```

## Guidelines

### 1. Formulate the Entry
- **Tense**: Always use **past tense** (e.g., "Added", "Improved", "Fixed").
- **Template**: `* <Description>. [#<PR_NUMBER>](https://github.com/flutter/devtools/pull/<PR_NUMBER>)`
- **Examples**:
  - `* Added support for XYZ. [#12345](https://github.com/flutter/devtools/pull/12345)`
  - `* Fixed a crash in the ABC screen. [#67890](https://github.com/flutter/devtools/pull/67890)`

### 2. Determine Section
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

### 3. Add to NEXT_RELEASE_NOTES.md
Use the provided utility script to insert the note safely. The script handles replacing the TODO placeholder if it's the first entry in that section.

```bash
dart .agents/skills/adding-release-notes/scripts/add_note.dart "Inspector updates" "Added XYZ support" 12345
```

### 4. Optional: Images
Add images to `packages/devtools_app/release_notes/images/` and reference them:
```markdown
![Accessible description](images/screenshot.png "Hover description")
```
**Constraint**: Use **dark mode** for screenshots.

## Resources
- [README.md](../../packages/devtools_app/release_notes/README.md): Official project guidance.
