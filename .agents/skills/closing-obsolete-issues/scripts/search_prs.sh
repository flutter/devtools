#!/bin/bash

# A script to search for PRs in flutter/devtools.
# Usage: ./search_prs.sh <query>

QUERY=$1

if [ -z "$QUERY" ]; then
  echo "Usage: $0 <query>"
  exit 1
fi

echo "--- SEARCHING PRs FOR: $QUERY ---"
gh search prs "$QUERY" --repo flutter/devtools --limit 20 --json number,title,state,url,createdAt -t '
{{range .}}
#{{.number}} {{.title}} ({{.state}})
Url: {{.url}}
Created: {{.createdAt}}
------------------------------------------------------------
{{end}}
'
