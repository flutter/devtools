#!/bin/bash

# Copyright 2020 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

echo "Generating code..."

echo $(pwd)

pushd packages

pushd devtools_test
flutter pub run build_runner build

echo "Adding 'ignore_for_file: require_trailing_commas' to generated mocks..."
TMP_FILE=/tmp/generated.mocks.dart
MOCK_FILE=devtools_test/lib/src/mocks/generated.mocks.dart
awk '!x{x=sub(/\/\/ ignore_for_file:/,"// ignore_for_file: require_trailing_commas\n// ignore_for_file:")}1' $MOCK_FILE > $TMP_FILE
mv $TMP_FILE $MOCK_FILE
rm $TMP_FILE
popd

popd
echo "Done generating code."
