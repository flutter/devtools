#!/bin/bash

# Copyright 2022 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Contains a path to this script, relative to the directory it was called from.
RELATIVE_PATH_TO_SCRIPT="${BASH_SOURCE[0]}"

# The directory that this script is located in.
TOOL_DIR=`dirname "${RELATIVE_PATH_TO_SCRIPT}"`

# The devtools root directory is assumed to be the parent of this directory.
DEVTOOLS_DIR="${TOOL_DIR}/.."


# Fast fail the script on failures.
set -ex

echo "generate_code.sh: generating code for devtools_app..."

echo $(pwd)

pushd $DEVTOOLS_DIR/packages/devtools_app

flutter pub run build_runner build --delete-conflicting-outputs

popd

echo "Generating code for devtools_test..."

pushd $DEVTOOLS_DIR/packages/devtools_test

flutter pub run build_runner build --delete-conflicting-outputs

MOCK_FILE=lib/src/mocks/generated.mocks.dart
if  ! grep -q require_trailing_commas "$MOCK_FILE" ; then
  echo "Adding 'ignore_for_file: require_trailing_commas' to generated mocks..."
  TMP_FILE=/tmp/generated.mocks.dart
  awk '!x{x=sub(/\/\/ ignore_for_file:/,"// ignore_for_file: require_trailing_commas\n// ignore_for_file:")}1' $MOCK_FILE > $TMP_FILE
  mv $TMP_FILE $MOCK_FILE
fi

popd

echo "generate_code.sh: done generating code."
