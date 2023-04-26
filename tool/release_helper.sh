#!/bin/bash -e

DEVTOOLS_REMOTE=$(git remote -v | grep "flutter/devtools.git" | grep "(fetch)"| tail -n1 | cut -w -f1)

# Change to the script's directory
cd "$(dirname "$0")"

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

NEW_VERSION=$(dart tool/update_version.dart current-version)

COMMIT_MESSAGE="Releasing from $ORIGINAL_VERSION to $NEW_VERSION"

# Stage the file, commit and push
git commit -a -m "$COMMIT_MESSAGE"

git push -u $DEVTOOLS_REMOTE $RELEASE_BRANCH

echo "Creating the PR"
echo

PR_URL=$(gh pr create --draft --title "$COMMIT_MESSAGE" --body "RELEASE_NOTE_EXCEPTION=Version Bump" $CREATION_FLAGS)


echo "Updating your flutter version to the most recent candidate."
echo
./tool/update_flutter_sdk.sh --local

echo "Your Draft release PR can be found at: $PR_URL"
echo
echo "$0 DONE: Build, run and test this release using: `dart ./tool/build_e2e.dart`"