#!/bin/bash
CURRENT_VERSION="$(sed -n -e 's/^.*version: //p' packages/devtools/pubspec.yaml)"

echo "Tagging version: $CURRENT_VERSION"
set -x #echo on

git tag -a v$CURRENT_VERSION -m "DevTools $CURRENT_VERSION"

git push upstream v$CURRENT_VERSION
