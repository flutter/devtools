#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x #echo on
echo "Editing .gitignore to comment out build directory"

pushd packages/devtools

pub get

rm -rf build
pub run build_runner build
mv ./build/packages ./build/pack

perl -pi -e "s/^build\/\$/\# build\//g" .gitignore

set +x
echo "Ready to publish."
echo "Verify the package works, then publish the package, and finally, revert the change to .gitignore."
echo "Publish by:"
echo "cd packages/devtools"
echo "pub publish"
echo "git checkout .gitignore"
popd
