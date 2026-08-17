#!/bin/bash

# Copyright 2024 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

# Fast fail the script on failures.
set -ex

source ./tool/ci/setup.sh

pushd $DEVTOOLS_DIR/tool
echo `pwd`

echo "Checking formatting..."
# Here, we use the dart instance from the flutter SDK.
dart format --output=none --set-exit-if-changed lib/ test/

flutter test test/
popd
