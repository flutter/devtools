#!/bin/bash

# Copyright 2020 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x #echo on
echo "Publishing devtools_* packages"

pushd packages/devtools_shared
flutter pub publish --force

popd
pushd packages/devtools_server
flutter pub publish --force

popd
pushd packages/devtools_testing
flutter pub publish --force

popd
pushd packages/devtools_app
flutter pub publish --force

popd
pushd packages/devtools
flutter pub publish --force

popd
