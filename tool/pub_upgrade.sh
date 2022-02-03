#!/bin/bash

# Copyright 2020 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# TODO(jacobr): use a consistent version solve across all packages like
# flutter does. https://github.com/flutter/devtools/issues/2240

echo "Running pub upgrade on all packages"
pushd packages

pushd devtools_app
flutter pub upgrade
popd

pushd devtools_shared
flutter pub upgrade
popd

pushd devtools_test
flutter pub upgrade
popd

popd
echo "Done running pub upgrade"
