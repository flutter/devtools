#!/bin/bash -ex
# echo '{ "draft": "true", "updateType": "release" }' | gh workflow run .github/workflows/daily-dev-bump.yaml --json --ref=more-bump

DEVTOOLS_REMOTE=$(git remote -v | grep "flutter/devtools.git" | grep "(fetch)"| tail -n1 | cut -w -f1)
TYPE=$1

cd ..

if [ -z "$DEVTOOLS_REMOTE" ] ; then
    echo "Couldn't find a remote that points to flutter/devtools.git"
    exit 1
fi

STATUS=$(git status -s)
if [[ ! -z  "$STATUS" ]] ; then
    echo "Make sure your working directory is clean before running the helper"
    exit 1
fi

MASTER="tmp_master_$(date +%s)"
git fetch $DEVTOOLS_REMOTE master
git checkout -b $MASTER $DEVTOOLS_REMOTE/master


RELEASE_BRANCH="clean_release_$(date +%s)"
git checkout -b "$RELEASE_BRANCH"

dart pub get

ORIGINAL_VERSION=$(dart tool/update_version.dart current-version)

dart tool/update_version.dart auto --type release
dart tool/bin/repo_tool.dart generate-changelog

NEW_VERSION=$(dart tool/update_version.dart current-version)

COMMIT_MESSAGE="Updating from $ORIGINAL_VERSION to $NEW_VERSION"

# Stage the file, commit and push
git commit -a -m "$COMMIT_MESSAGE"


PR_URL=$(gh pr create --title "$COMMIT_MESSAGE" --body "RELEASE_NOTE_EXCEPTION=Automated Version Bump" $CREATION_FLAGS)
