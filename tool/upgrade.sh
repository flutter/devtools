#!/bin/bash

# Copyright 2023 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

echo "upgrade.sh: upgrading packages..."

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR="$SCRIPT_DIR/.."

pushd "$ROOT_DIR/packages/devtools_shared"
flutter pub upgrade
popd

pushd "$ROOT_DIR/packages/devtools_test"
flutter pub upgrade
popd

pushd "$ROOT_DIR/packages/devtools_app_shared"
flutter pub upgrade
popd

pushd "$ROOT_DIR/packages/devtools_app"
flutter pub upgrade
popd

pushd "$ROOT_DIR/packages/devtools_extensions"
flutter pub upgrade
popd

pushd "$ROOT_DIR/packages/devtools_extensions/example/app_that_uses_foo"
flutter pub upgrade
popd

pushd "$ROOT_DIR/packages/devtools_extensions/example/foo/packages/foo"
flutter pub upgrade
popd

pushd "$ROOT_DIR/packages/devtools_extensions/example/foo/packages/foo_devtools_extension"
flutter pub upgrade
popd

echo "upgrade.sh: upgraded packages."
