#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x #echo on
echo "Editing .gitignore to comment out build directory"

pushd packages/devtools_app
flutter pub get
popd

tool/build_release.sh

pushd packages/devtools
pub get
perl -pi -e "s/^build\/\$/\# build\//g" .gitignore
popd

echo "Updating pubspecs to remove dependency overrides for development"
perl -pi -e 's/^.*#OVERRIDE_FOR_DEVELOPMENT.*//' packages/*/pubspec.yaml

set +x
echo "Ready to publish."
echo "Verify the package works, then follow the steps in tool/README.md to publish"
