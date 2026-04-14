# Skill Authoring Examples

## 1. Effective YAML Frontmatter

**Good (Gerund + What/When Description):**
```yaml
---
name: processing-logs
description: Extracts and summarizes error patterns from system logs. Use when the user asks to analyze logs or troubleshoot runtime errors.
---
```

**Bad (Vague + First Person):**
```yaml
---
name: helper-tool
description: I can help you look at files and tell you what is wrong.
---
```

## 2. Progressive Disclosure Pattern

If a skill has a complex API or many configuration options, do not put them all in `SKILL.md`.

**SKILL.md:**
```markdown
## Advanced Configuration
For detailed information on environment variables and performance tuning, see [CONFIG.md](CONFIG.md).
```

## 3. Workflow Patterns

Always use checklists to track state.

```markdown
## Workflow
Copy this checklist:
- [ ] Step 1: Analyze input.
- [ ] Step 2: Generate draft.
- [ ] Step 3: Run validation script.
```

## 4. Automation with Dart

All scripts should be written in Dart and placed in the `scripts/` directory.

**Good Script Usage:**
```markdown
## Step 4: Add the entry
Use the provided utility script to insert the note safely.
`dart .agents/skills/adding-release-notes/scripts/add_note.dart "Inspector updates" "Added XYZ" TODO`
```

## 5. Anti-Patterns to Avoid

- **Prohibited**: Using non-Dart languages for utility scripts.
- **Prohibited**: Using Windows-style paths (always use `/`).
- **Prohibited**: Offering too many options (narrow the scope to recommended defaults).
- **Prohibited**: Verbose background stories (Claude already knows how to code).
- **Prohibited**: Interactive prompts (Agents should be autonomous, not ask for permission at every step).
