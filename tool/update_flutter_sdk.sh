#!/bin/bash

# Copyright 2021 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -e
# Any subsequent commands failure will cause this script to exit immediately

# Contains a path to this script, relative to the directory it was called from.
RELATIVE_PATH_TO_SCRIPT="${BASH_SOURCE[0]}"

# The directory that this script is located in.
TOOL_DIR=`dirname "${RELATIVE_PATH_TO_SCRIPT}"`

cd `$TOOL_DIR`
dart pub get
REQUIRED_FLUTTER_VERSION=`dart $TOOL_DIR/bin/repo_tool.dart latest-flutter-candidate | tail -n 1`
cd -

if [[ $1 = "--local" ]]; then
  echo "STATUS: Updating local Flutter checkout to version '$REQUIRED_FLUTTER_VERSION'."

  FLUTTER_EXE=`which flutter`
  FLUTTER_BIN=`dirname "${FLUTTER_EXE}"`
  FLUTTER_DIR="$FLUTTER_BIN/.."

  pushd $FLUTTER_DIR
  git pull upstream master
  git fetch upstream
  git checkout $REQUIRED_FLUTTER_VERSION
  flutter --version
  popd

  echo "STATUS: Finished updating local Flutter checkout."
fi

FLUTTER_DIR="$TOOL_DIR/flutter-sdk"
PATH="$FLUTTER_DIR/bin":$PATH

echo "STATUS: Updating 'tool/flutter-sdk' to version '$REQUIRED_FLUTTER_VERSION'."

if [ -d "$FLUTTER_DIR" ]; then
  echo "STATUS: 'tool/flutter-sdk' directory already exists"

  # switch to the specified version
  pushd $FLUTTER_DIR
  git fetch
  git checkout $REQUIRED_FLUTTER_VERSION
  ./bin/flutter --version
  popd
else
  echo "STATUS: 'tool/flutter-sdk' directory does not exist - cloning it now"

  # clone the flutter repo and switch to the specified version
  git clone https://github.com/flutter/flutter flutter-sdk
  pushd flutter-sdk
  git checkout $REQUIRED_FLUTTER_VERSION
  ./bin/flutter --version
  popd
fi

echo "STATUS: Finished updating 'tool/flutter-sdk'."
