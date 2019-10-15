#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x #echo on

pushd packages/devtools_app

# TODO(terry): Look at using dependency_overrides to work around transitive dependencies w/ import.
# Shared file between devtoools_server and devtools_app
echo '// DO NOT EDIT - edit devtools_server/lib/src/devtools_api.dart.' > lib/src/devtools_api.dart
cat ../devtools_server/lib/src/devtools_api.dart >> lib/src/devtools_api.dart

rm -rf build
rm -rf ../devtools/build
flutter pub run build_runner build -o web:build --release
mv ./build/packages ./build/pack

# move release to the devtools package from the devtools_app package for deployment
mv build ../devtools
popd
