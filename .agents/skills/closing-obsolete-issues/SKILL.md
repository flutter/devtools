---
name: closing-obsolete-issues
description: Find and close obsolete, stale, or not reproducible issues in the flutter/devtools repository.
---

# Closing Obsolete Issues

Use this skill to find old, outdated issues in the `flutter/devtools` repository that can be closed because they have been fixed, are stale, obsolete, or not reproducible.

## Instructions

1. **Identify Target Issues**:
   - Use the GitHub CLI (`gh`) to search for the oldest open issues.
   - Use any label that the user gives you, or none if the user does not specify any issue labels.
   - Sort by creation date (`created-asc`) or last update (`updated-asc`) to find the most likely candidates for being outdated.
   - Fetch at least 20-30 candidates.
   - Example command (with label): `gh issue list --repo flutter/devtools --search "label:bug is:open sort:created-asc" --limit 30 | cat`
   - Example command (without label): `gh issue list --repo flutter/devtools --search "is:open sort:created-asc" --limit 30 | cat`

2. **Investigate Status**:
   - For each candidate, analyze its description and comments.
   - **Pro Tip**: Use the bundled script `scripts/fetch_issue_details.sh <number>` to get a comprehensive view of the issue and its comments.
   - Compare the issue's request or reported bug with the current state of the codebase.
   - Refer to `references/rationale_templates.md` for a library of common reasons issues become outdated in DevTools.

3. **Draft and Review Closing Comments (CRITICAL MANDATE)**:
   - For issues identified as candidates for closing, draft a detailed comment for each explaining *why* it can be closed.
   - **Style Constraint**: DO NOT use em dashes (—) in the comments. Use hyphens (-) or colons (:) instead.
   - **Template**: Consult `references/rationale_templates.md` for wording inspiration.
   - Each comment MUST end with: "If there is more work to do here, please let us know by filing a new issue with up to date information. Thanks!"
   - **User Approval Required**: You MUST present the identified issues (including URLs to the issues for easy navigation) and their drafted comments to the user and obtain explicit approval BEFORE running any command that closes an issue.

4. **Iterate on Skill Knowledge (Learning Loop)**:
   - If you discover a new, distinct category of closing rationale that is not covered in `references/rationale_templates.md`, **update the reference file** to include it.

5. **Execute and Summarize**:
   - Once approved, use `gh issue close` with the `-c` flag to post the comment and close the issue.
   - Provide the user with a clean bulleted list of links to each closing comment.

## Tips

- Use `grep_search` or `find_by_name` to check the current codebase for references to the issue or relevant code.
- Look for related PRs that might have fixed the issue but didn't close it automatically.
- For issues reporting specific versions, check the current DevTools version in `packages/devtools_app/pubspec.yaml` to determine if the reported version is very old.
