#!/bin/bash

# Copyright 2021 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Any subsequent commands failure will cause this script to exit immediately
set -e

UPDATE_LOCALLY=$1

# Contains a path to this script, relative to the directory it was called from.
RELATIVE_PATH_TO_SCRIPT="${BASH_SOURCE[0]}"

# The directory that this script is located in.
TOOL_DIR=`dirname "${RELATIVE_PATH_TO_SCRIPT}"`

pushd "$TOOL_DIR"
dart pub get
REQUIRED_FLUTTER_BRANCH=`./latest_flutter_candidate.sh`

echo "REQUIRED_FLUTTER_BRANCH: $REQUIRED_FLUTTER_BRANCH"

if [[ $UPDATE_LOCALLY = "--local" ]]; then
  echo "STATUS: Updating local Flutter checkout to branch '$REQUIRED_FLUTTER_BRANCH'."

  FLUTTER_EXE=`which flutter`
  FLUTTER_BIN=`dirname "${FLUTTER_EXE}"`
  FLUTTER_DIR="$FLUTTER_BIN/.."

  pushd $FLUTTER_DIR
  # TODO: add a check here to verify that upstream is the remote flutter/flutter
  # Stash any local flutter SDK changes if they exist.
  git stash
  git checkout upstream/master
  git reset --hard upstream/master
  git fetch upstream
  git checkout $REQUIRED_FLUTTER_BRANCH -f
  flutter --version
  popd

  echo "STATUS: Finished updating local Flutter checkout."
fi

FLUTTER_DIR="flutter-sdk"
PATH="$FLUTTER_DIR/bin":$PATH

echo "STATUS: Updating 'tool/flutter-sdk' to branch '$REQUIRED_FLUTTER_BRANCH'."

if [ -d "$FLUTTER_DIR" ]; then
  echo "STATUS: 'tool/$FLUTTER_DIR' directory already exists"

  # switch to the specified version
  pushd $FLUTTER_DIR
  git fetch
  git checkout $REQUIRED_FLUTTER_BRANCH -f
  ./bin/flutter --version
  popd
else
  echo "STATUS: 'tool/$FLUTTER_DIR' directory does not exist - cloning it now"

  # clone the flutter repo and switch to the specified version
  git clone https://github.com/flutter/flutter "$FLUTTER_DIR"
  pushd "$FLUTTER_DIR"
  git checkout $REQUIRED_FLUTTER_BRANCH
  ./bin/flutter --version
  popd
fi

popd
echo "STATUS: Finished updating 'tool/flutter-sdk'."
