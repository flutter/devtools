#!/bin/bash

# Copyright 2018 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

# Fast fail the script on failures.
set -ex

source ./tool/ci/setup.sh

pushd $DEVTOOLS_DIR/packages/devtools_app
flutter test -j, --concurrency=1 benchmark/devtools_benchmarks_test.dart
popd
