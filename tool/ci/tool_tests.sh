#!/bin/bash

# Copyright 2024 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

# Fast fail the script on failures.
set -ex

source ./tool/ci/setup.sh

pushd $DEVTOOLS_DIR/tool
echo `pwd`
flutter test test/
popd