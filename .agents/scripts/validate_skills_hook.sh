#!/bin/bash

# Copyright 2026 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

# Read AGY stdin JSON payload
INPUT=$(cat)

# Extract TargetFile from tool call arguments
TARGET_FILE=$(echo "$INPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('toolCall', {}).get('args', {}).get('TargetFile', ''))" 2>/dev/null)

# Check if a skill file was modified
if [[ "$TARGET_FILE" == *"SKILL.md"* ]] || [[ "$TARGET_FILE" == *".agents/skills"* ]]; then
  echo "Skill edit detected: $TARGET_FILE" >&2
  echo "Running skills_lint..." >&2
  
  # Run the skills linter from tool/ directory
  (cd tool && flutter pub run skills_lint)
fi

# PostToolUse expects an empty JSON object on stdout
echo "{}"
