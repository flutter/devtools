#!/bin/bash

# Copyright 2022 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

echo "Generating code..."

echo $(pwd)

pushd packages/devtools_test

flutter pub run build_runner build --delete-conflicting-outputs

MOCK_FILE=lib/src/mocks/generated.mocks.dart
if  ! grep -q require_trailing_commas "$MOCK_FILE" ; then
  echo "Adding 'ignore_for_file: require_trailing_commas' to generated mocks..."
  TMP_FILE=/tmp/generated.mocks.dart
  awk '!x{x=sub(/\/\/ ignore_for_file:/,"// ignore_for_file: require_trailing_commas\n// ignore_for_file:")}1' $MOCK_FILE > $TMP_FILE
  mv $TMP_FILE $MOCK_FILE
fi

popd

echo "Done generating code."
