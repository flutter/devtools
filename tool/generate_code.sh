#!/bin/bash

# Copyright 2020 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

echo "Generating code..."
pushd packages

pushd devtools_test
flutter pub run build_runner build
popd

popd
echo "Done generating code."
