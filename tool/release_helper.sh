#!/bin/bash -e

DEVTOOLS_REMOTE=$(git remote -v | grep "flutter/devtools.git" | grep "(fetch)"| tail -n1 | cut -w -f1)


if [ -z "$DEVTOOLS_REMOTE" ] ; then
    echo "Couldn't find a remote that points to flutter/devtools.git"
    exit 1
fi

STATUS=$(git status -s)
if [[ ! -z  "$STATUS" ]] ; then
    echo "Make sure your working directory is clean before running the helper"
    exit 1
fi

echo "Getting a fresh copy of master"
echo
MASTER="tmp_master_$(date +%s)"
git fetch $DEVTOOLS_REMOTE master
git checkout -b $MASTER $DEVTOOLS_REMOTE/master


RELEASE_BRANCH="clean_release_$(date +%s)"
git checkout -b "$RELEASE_BRANCH"

echo "Ensuring ./tool packages are ready"
echo
dart pub get

cd ..

ORIGINAL_VERSION=$(dart tool/update_version.dart current-version)

echo "Setting the release version"
echo
dart tool/update_version.dart auto --type release

echo "Updating the changelog"
echo
dart tool/bin/repo_tool.dart generate-changelog

NEW_VERSION=$(dart tool/update_version.dart current-version)

COMMIT_MESSAGE="Releasing from $ORIGINAL_VERSION to $NEW_VERSION"

# Stage the file, commit and push
git commit -a -m "$COMMIT_MESSAGE"

git push -u $DEVTOOLS_REMOTE $RELEASE_BRANCH
echo "Creating the PR"
echo
PR_URL=$(gh pr create --draft --title "$COMMIT_MESSAGE" --body "RELEASE_NOTE_EXCEPTION=Automated Version Bump" $CREATION_FLAGS)

echo "Release PR created successfully: $PR_URL"
echo
echo "Updating your flutter version to the most recent candidate."
echo
./tool/update_flutter_sdk.sh --local
echo
echo "$0 DONE: You can now start testing devtools to make sure it is ready for release."