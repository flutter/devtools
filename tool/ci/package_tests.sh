#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

source ./tool/ci/setup.sh

if [ "$PACKAGE" = "devtools_app_shared" ]; then

    pushd $DEVTOOLS_DIR/packages/devtools_app_shared
    echo `pwd`
    flutter test test/
    popd

elif [ "$PACKAGE" = "devtools_extensions" ]; then 

    pushd $DEVTOOLS_DIR/packages/devtools_extensions
    echo `pwd`
    flutter test test/*_test.dart
    flutter test test/web --platform chrome
    popd

elif [ "$PACKAGE" = "devtools_shared" ]; then 

    pushd $DEVTOOLS_DIR/packages/devtools_shared
    echo `pwd`
    dart test test/
    popd

fi
