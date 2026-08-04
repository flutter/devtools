#!/bin/bash

# Copyright 2026 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

# Check if any skill file was modified in git working directory
MODIFIED_SKILLS=$(git diff --name-only HEAD 2>/dev/null | grep "\.agents/skills/.*SKILL\.md$")

if [ -n "$MODIFIED_SKILLS" ]; then
  # Inject ephemeral message instructing AGY to review the modified skill
  cat <<EOF
{
  "injectSteps": [
    {
      "ephemeralMessage": "AGY Skill Hook: The following skill files were modified: ${MODIFIED_SKILLS}. Please review the edited skills to ensure they follow best practices (conciseness, clear frontmatter) and verify that instructions are not repetitive or duplicative with existing style guides or skills."
    }
  ]
}
EOF
else
  echo "{}"
fi
