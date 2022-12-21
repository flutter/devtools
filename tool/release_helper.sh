#!/bin/bash -ex

DEVTOOLS_REMOTE=$(git remote -v | grep "flutter/devtools.git" | grep "(fetch)"| tail -n1 | cut -w -f1)
TYPE=$1

if [ -z "$TYPE" ] ; then
    echo "$0 expects a type as a first parameter"
    exit 1
fi

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
git switch -c $MASTER $DEVTOOLS_REMOTE/master


RELEASE_BRANCH="clean_release_$(date +%s)"
NEXT_BRANCH="next_version_$(date +%s)"

git checkout -b $RELEASE_BRANCH;
COMMIT_MESSAGE=$(dart tool/update_version.dart auto -d -t release)
dart tool/update_version.dart auto -t release
dart tool/bin/repo_tool.dart generate-changelog
git commit -am "$COMMIT_MESSAGE"

git checkout -b $NEXT_BRANCH;
TYPE_BUMP_COMMIT_MESSAGE=$(dart tool/update_version.dart auto -d -t $TYPE)
dart tool/update_version.dart auto -t $TYPE
git commit -am "$TYPE_BUMP_COMMIT_MESSAGE"

DEV_BUMP_COMMIT_MESSAGE=$(dart tool/update_version.dart auto -d -t dev)
dart tool/update_version.dart auto -t dev # set the first dev version
git commit -am "$DEV_BUMP_COMMIT_MESSAGE"


git checkout $RELEASE_BRANCH

echo "------------------------"
echo "RELEASE HELPER FINISHED"
echo "The branches created are as follows:"
echo
echo "DEVTOOLS_RELEASE_BRANCH=\"$RELEASE_BRANCH\";"
echo "DEVTOOLS_NEXT_BRANCH=\"$NEXT_BRANCH\";"

export DEVTOOLS_RELEASE_BRANCH="$RELEASE_BRANCH"
export DEVTOOLS_NEXT_BRANCH="$NEXT_BRANCH"
