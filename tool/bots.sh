#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DEVTOOLS_DIR=$SCRIPT_DIR/..

# TODO: Also support windows on github actions.
if [[ $RUNNER_OS == "Windows" ]]; then
    echo Installing Google Chrome Stable...
    # Install Chrome via Chocolatey while `addons: chrome` doesn't seem to work on Windows yet
    # https://travis-ci.community/t/installing-google-chrome-stable-but-i-cant-find-it-anywhere/2118
    choco install googlechrome --acceptlicense --yes --no-progress --ignore-checksums
fi

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

# Make sure Flutter sdk has been provided
if [ ! -d "./flutter-sdk" ]; then
    echo "Expected ./flutter-sdk to exist"
    exit 1;
fi

# Look in the dart bin dir first, then the flutter one, then the one for the
# devtools repo. We don't use the dart script from flutter/bin as that script
# can and does print 'Waiting for another flutter command...' at inopportune
# times.
export PATH=`pwd`/flutter-sdk/bin/cache/dart-sdk/bin:`pwd`/flutter-sdk/bin:`pwd`/bin:$PATH

# Look up the latest flutter candidate (this is the latest flutter version in g3)
# TODO(https://github.com/flutter/devtools/issues/4591): re-write this script as a
# shell script so we won't have to incurr the cost of building flutter tool twice.

flutter config --no-analytics
flutter doctor

# We should be using dart from ../flutter-sdk/bin/cache/dart-sdk/dart.
echo "which flutter: " `which flutter`
echo "which dart: " `which dart`

# Disable analytics to ensure that the welcome message for the dart cli tooling
# doesn't interrupt the CI bots.
dart --disable-analytics

# Print out the versions and ensure we can call Dart, Pub, and Flutter.
flutter --version
dart --version

# Fetch dependencies for the tool/ directory
pushd $DEVTOOLS_DIR/tool
flutter pub get
popd

# Ensure the devtools_tool command is available
export PATH="$PATH":"$DEVTOOLS_DIR/tool/bin"


# Fetch dependencies
devtools_tool pub-get --only-main

# Generate code.
bash tool/generate_code.sh

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
