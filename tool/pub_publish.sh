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
if ! flutter pub publish --force; then
    echo "flutter pub publish devtools_server failed."
    exit -1
fi

popd
pushd packages/devtools_testing
if ! flutter pub publish --force; then
    echo "flutter pub publish devtools_testing failed."
    exit -1
fi

popd
pushd packages/devtools_app
if ! flutter pub publish --force; then
    echo "flutter pub publish devtools_app failed."
    exit -1
fi

popd
pushd packages/devtools
if ! flutter pub publish --force; then
    echo "flutter pub publish devtools failed."
    exit -1
fi

popd
