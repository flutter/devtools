#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

source ./tool/ci/setup.sh

pushd $DEVTOOLS_DIR/packages/devtools_app
flutter test test_benchmarks/
popd
