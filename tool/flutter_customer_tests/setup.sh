#!/bin/bash -e

# Copyright 2025 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

# Script to generate mocks for Devtools from the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

# Ensure the `dt` executable is on PATH.
root_dir=$(pwd)
tool_dir="$root_dir/tool/bin"
export PATH=$PATH:$tool_dir
# Force `dt` to use the current Flutter (which is available on PATH).
export DEVTOOLS_TOOL_FLUTTER_FROM_PATH=true

cd tool
flutter pub get

dt pub-get --upgrade
dt generate-code --no-pub-get

cd ..
