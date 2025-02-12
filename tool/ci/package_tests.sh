#!/bin/bash

# Copyright 2018 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
    # Skip this on Windows because `flutter test --platform chrome`
    # appears to hang there.
    # https://github.com/flutter/flutter/issues/162798
    if [[ $RUNNER_OS != "Windows" ]]; then
        flutter test test/web --platform chrome
    fi
    popd

elif [ "$PACKAGE" = "devtools_shared" ]; then

    pushd $DEVTOOLS_DIR/packages/devtools_shared
    echo `pwd`
    dart test test/
    popd

fi
