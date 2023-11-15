#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# This section must be at the top of each CI script.
# ---------------- Begin ---------------- #

# Fast fail the script on failures.
set -ex

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DEVTOOLS_DIR=$SCRIPT_DIR/../..

# In GitBash on Windows, we have to call flutter.bat so we alias them in this
# script to call the correct one based on the OS.
function flutter {
    # TODO: Also support windows on github actions.
    if [[ $RUNNER_OS == "Windows" ]]; then
        command flutter.bat "$@"
    else
        command flutter "$@"
    fi
}

# ---------------- End ---------------- #

./tool/ci/setup.sh

# Change the CI to the packages/devtools_app directory.
pushd $DEVTOOLS_DIR/packages/devtools_app
echo `pwd`

if [ "$BOT" = "main" ]; then

    # Verify that dart format has been run.
    echo "Checking formatting..."
    # Here, we use the dart instance from the flutter sdk.
    $(dirname $(which flutter))/dart format --output=none --set-exit-if-changed .

    # Make sure the app versions are in sync.
    devtools_tool repo-check

    # Get packages
    devtools_tool pub-get

    # Analyze the code
    devtools_tool analyze

    popd

    # Test the `devtools_app_shared`, `devtools_shared` and `devtools_extensions` package tests on the
    # main bot.
    pushd $DEVTOOLS_DIR/packages/devtools_app_shared
    echo `pwd`
    flutter test test/
    popd

    pushd $DEVTOOLS_DIR/packages/devtools_shared
    echo `pwd`
    flutter test test/
    popd

    pushd $DEVTOOLS_DIR/packages/devtools_extensions
    echo `pwd`
    flutter test test/
    popd

    # Change the directory back to devtools_app.
    pushd $DEVTOOLS_DIR/packages/devtools_app
    echo `pwd`

elif [ "$BOT" = "build_ddc" ]; then

    # TODO(https://github.com/flutter/flutter/issues/43538): Remove workaround.
    flutter build web --pwa-strategy=none --no-tree-shake-icons

elif [ "$BOT" = "build_dart2js" ]; then

    flutter build web --release --no-tree-shake-icons

elif [[ "$BOT" == "test_ddc" || "$BOT" == "test_dart2js" ]]; then
    if [ "$BOT" == "test_dart2js" ]; then
        USE_WEBDEV_RELEASE=true
    else
        USE_WEBDEV_RELEASE=false
    fi
    echo "USE_WEBDEV_RELEASE = $USE_WEBDEV_RELEASE"

    FILES="test/"
    if [ "$ONLY_GOLDEN" = "true" ]; then
        # Set the test files to only those containing golden test
        FILES=$(grep -rl "matchesDevToolsGolden\|matchesGoldenFile" test | grep "_test.dart$" | tr '\n' ' ')
    fi

    # TODO(https://github.com/flutter/devtools/issues/1987): once this issue is fixed,
    # we may need to explicitly exclude running integration_tests here (this is what we
    # used to do when integration tests were enabled).
    if [ "$PLATFORM" = "vm" ]; then
        WEBDEV_RELEASE=$USE_WEBDEV_RELEASE flutter test $FILES
    elif [ "$PLATFORM" = "chrome" ]; then
        WEBDEV_RELEASE=$USE_WEBDEV_RELEASE flutter test --platform chrome $FILES
    else
        echo "unknown test platform"
        exit 1
    fi

# TODO(https://github.com/flutter/devtools/issues/1987): consider running integration tests
# for a DDC build of DevTools
# elif [ "$BOT" = "integration_ddc" ]; then

# TODO(https://github.com/flutter/devtools/issues/1987): rewrite legacy integration tests.
elif [ "$BOT" = "integration_dart2js" ]; then
    if [ "$DEVTOOLS_PACKAGE" = "devtools_app" ]; then
        flutter pub get

        # TODO(https://github.com/flutter/flutter/issues/118470): remove this warning.
        echo "Preparing to run integration tests.\nWarning: if you see the exception \
    'Web Driver Command WebDriverCommandType.screenshot failed while waiting for driver side', \
    this is a known issue and likely means that the golden image check failed (see \
    https://github.com/flutter/flutter/issues/118470). Run the test locally to see if new \
    images under a 'failures/' directory are created as a result of the test run:\n\
    $ dart run integration_test/run_tests.dart --headless"

        if [ "$DEVICE" = "flutter" ]; then
            dart run integration_test/run_tests.dart --headless --shard="$SHARD"
        elif [ "$DEVICE" = "flutter-web" ]; then
            dart run integration_test/run_tests.dart --test-app-device=chrome --headless --shard="$SHARD"
        elif [ "$DEVICE" = "dart-cli" ]; then
            dart run integration_test/run_tests.dart --test-app-device=cli --headless --shard="$SHARD"
        fi
    elif [ "$DEVTOOLS_PACKAGE" = "devtools_extensions" ]; then
        pushd $DEVTOOLS_DIR/packages/devtools_extensions
        dart run integration_test/run_tests.dart --headless
        popd
    fi

elif [ "$BOT" = "benchmarks_dart2js" ]; then

    dart run test_benchmarks/web_bundle_size_test.dart

fi

popd
