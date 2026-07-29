---
name: reviewing-prs
description: General workflow for fetching, inspecting, reviewing GitHub Pull Requests using the gh CLI, drafting user-aligned review comments, and securing approval before posting. Use when asked to review a GitHub PR or pull request.
---

# Reviewing Pull Requests

This skill outlines the workflow for inspecting GitHub Pull Requests using the `gh` CLI, drafting review feedback, and securing user approval before posting review comments.

## Approval Safeguard (Strict Requirement)

> [!IMPORTANT]
> **NEVER post comments or reviews to GitHub without explicit prior user approval.**
> Always present draft review comments to the user in natural language first. Only execute write commands (`gh pr comment`, `gh pr review`) after the user approves.

## Workflow

### 1. Request Information via GitHub CLI

- **PR Details**:
  ```bash
  gh pr view <pr-number> --repo <owner/repo> --json title,body,author,state,headRefName,baseRefName,comments,reviews,files
  ```
- **Code Diff**:
  ```bash
  gh pr diff <pr-number> --repo <owner/repo>
  ```
- **Existing Inline Comments**:
  ```bash
  gh api repos/<owner/repo>/pulls/<pr-number>/comments
  ```
- **CI / Status Checks**:
  ```bash
  gh pr checks <pr-number> --repo <owner/repo>
  ```

### 2. Inspect Context & Prior Feedback

- Read the PR description, linked issues, and full diff.
- Verify whether existing bot or human comments have already been addressed in subsequent commits.

### 3. Draft Review Comments

- Keep comments direct, concise, and focused on code quality and correctness.
- **Approvals**: Keep comments concise (`LGTM` or `A couple comments but lgtm.`). Avoid fluffy praise or re-summarizing the PR.
- **Actionable Feedback**: Reference specific files, line numbers, and rationale when leaving suggestions.

### 4. Present Draft & Post Only Upon User Approval

> [!IMPORTANT]
> **NEVER post comments or reviews to GitHub without explicit prior user approval.**

1. Present the drafted review comments to the user in your response window.
2. Ask for confirmation: *"Would you like me to submit this review to GitHub?"*
3. Once explicitly approved by the user, post the review:
   ```bash
   gh pr review <pr-number> --repo <owner/repo> --comment --body "<approved review text>"
   ```
