#!/bin/bash

# Copyright 2023 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

echo "upgrade.sh: upgrading packages..."

pushd packages/devtools_shared
flutter pub upgrade
popd

pushd packages/devtools_test
flutter pub upgrade
popd

pushd packages/devtools_app_shared
flutter pub upgrade
popd

pushd packages/devtools_app
flutter pub upgrade
popd

pushd packages/devtools_extensions
flutter pub upgrade
popd

echo "upgrade.sh: upgraded packages."
