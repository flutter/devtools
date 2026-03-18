---
name: authoring-skills
description: Guides the creation of high-quality, effective skills for agentic workflows. Use when creating or modifying skills in the .agents/skills/ directory.
---

# Authoring Skills

When creating or modifying skills in this repository, follow these best practices:

- **Antigravity Guidelines**: [Skill authoring best practices](https://antigravity.google/docs/skills)
- **Anthropic Guidelines**: [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

## Repository-Specific Guidelines

- **Location**: All skills must be placed in the `.agents/skills/` directory.
- **Avoid Duplication**: Before creating a skill, check if one already exists in the [flutter/skills](https://github.com/flutter/skills/tree/main/skills) repository. If it does, do not create a local skill; instead, instruct the user to install it via `npx`.
- **Naming**: Use the gerund form (**verb-ing-noun**) or **noun-phrase** (e.g., `authoring-skills`, `adding-release-notes`). Use only lowercase letters, numbers, and hyphens.
- **Conciseness**: Prioritize brevity in `SKILL.md`. Agents are already highly capable; only provide context they don't already have.
- **Automation**: Any utility scripts placed in the `scripts/` directory MUST be written in **Dart**.
- **Progressive Disclosure**: Use the patterns below to organize instructions effectively:
  - [CHECKLIST.md](CHECKLIST.md): Template for tracking skill development progress.
  - [EXAMPLES.md](EXAMPLES.md): Local examples and anti-patterns.
