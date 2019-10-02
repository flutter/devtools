#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

if [ "$TRAVIS_DART_VERSION" = "stable" ]; then
    echo "Cloning stable Flutter branch"
    git clone https://github.com/flutter/flutter.git --branch stable ../flutter

    # Set the suffix so we use stable goldens.
    export DART_VM_OPTIONS="-DGOLDENS_SUFFIX=_stable"
else
    echo "Cloning master Flutter branch"
    git clone https://github.com/flutter/flutter.git ../flutter
fi

pushd ..
export PATH=`pwd`/flutter/bin:`pwd`/flutter/bin/cache/dart-sdk/bin:$PATH
popd

flutter config --no-analytics
