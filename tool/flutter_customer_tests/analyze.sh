#!/bin/bash -e

# Copyright 2025 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

# Script to analyze the devtools repo for the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

# At this point we can expect that mocks have already been generated from
# setup.sh, which is called from the setup steps in
# https://github.com/flutter/tests/blob/main/registry/flutter_devtools.test.

# Ensure the `dt` executable is on PATH.
root_dir=$(pwd)
tool_dir="$root_dir/tool/bin"
export PATH=$PATH:$tool_dir
# Force `dt` to use the current Flutter (which is available on PATH).
export DEVTOOLS_TOOL_FLUTTER_FROM_PATH=true

cd tool

# We do not need to run `dt pub-get` here because the Flutter customer
# test retgistry script already runs `flutter packages get` on the
# DevTools packages.

# Skip unimportant directories to speed up analysis.
# Unimportant directories are defined in tool/lib/commands/analyze.dart.
dt analyze --no-fatal-infos --skip-unimportant

cd ..
