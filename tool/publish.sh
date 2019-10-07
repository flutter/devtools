#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x #echo on
echo "Editing .gitignore to comment out build directory"

pushd packages/devtools_app
pub get
popd

tool/build_release.sh

pushd packages/devtools
pub get
perl -pi -e "s/^build\/\$/\# build\//g" .gitignore
popd

set +x
echo "Ready to publish."
echo "Verify the package works, then publish the package, and finally, revert the change to .gitignore."
echo "Publish by:"
echo "cd packages/devtools"
echo "pub publish"
echo "git checkout .gitignore"
