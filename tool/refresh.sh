#!/bin/bash

# Copyright 2022 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

echo "Refreshing local clone..."

pushd packages/devtools_app
flutter pub upgrade
flutter pub get
popd

pushd packages/devtools_test
flutter pub get
popd

bash tool/generate_code.sh

echo "Refreshed local clone."
