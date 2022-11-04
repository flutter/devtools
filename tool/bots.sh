#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -ex

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

# Get Flutter.
echo "Cloning the Flutter master branch"
# if ./flutter-sdk exists then fetch master
# otherwise clone it and run it fresh
#NOTES
# - make sure whole test runs on candidate
# - cache entire flutter candidate branch
# - cache build artifacts from devtools
if [ -d "/path/to/dir" ]; then
    pushd ./flutter-sdk
    git fetch --All
    popd
else
    git clone https://github.com/flutter/flutter.git ./flutter-sdk
fi

# Look in the dart bin dir first, then the flutter one, then the one for the
# devtools repo. We don't use the dart script from flutter/bin as that script
# can and does print 'Waiting for another flutter command...' at inopportune
# times.
export PATH=`pwd`/flutter-sdk/bin/cache/dart-sdk/bin:`pwd`/flutter-sdk/bin:`pwd`/bin:$PATH

# Look up the latest flutter candidate (this is the latest flutter version in g3)
# TODO(https://github.com/flutter/devtools/issues/4591): re-write this script as a
# shell script so we won't have to incurr the cost of building flutter tool twice.
echo "Looking up the latest Flutter candidate branch"
pushd packages/devtools_app
LATEST_FLUTTER_CANDIDATE=`repo_tool latest-flutter-candidate --githubToken=$AUTH_TOKEN | tail -n 1`
popd

pushd flutter-sdk
git checkout $LATEST_FLUTTER_CANDIDATE
popd

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

# Generate code.
pushd packages/devtools_app
flutter pub get
popd
pushd packages/devtools_test
flutter pub get
popd
bash tool/generate_code.sh

# Change the CI to the packages/devtools_app directory.
pushd packages/devtools_app
echo `pwd`

if [ "$BOT" = "main" ]; then

    # Provision our packages.
    flutter pub get

    # Verify that dart format has been run.
    echo "Checking formatting..."
    # Here, we use the dart instance from the flutter sdk.
    $(dirname $(which flutter))/dart format --output=none --set-exit-if-changed .

    # Make sure the app versions are in sync.
    repo_tool repo-check

    # Get packages
    repo_tool packages-get

    # Analyze the code
    repo_tool analyze

    # Ensure we can build the app.
    flutter build web --release

    # Test the devtools_shared package tests on the main bot.
    popd
    pushd packages/devtools_shared
    echo `pwd`

    flutter test test/
    popd

    # Change the directory back to devtools_app.
    pushd packages/devtools_app
    echo `pwd`

elif [ "$BOT" = "test_ddc" ]; then

    # Provision our packages.
    flutter pub get

    # TODO(https://github.com/flutter/flutter/issues/43538): Remove workaround.
    flutter build web --pwa-strategy=none --no-tree-shake-icons

    # TODO(https://github.com/flutter/devtools/issues/1987): once this issue is fixed,
    # we may need to explicitly exclude running integration_tests here (this is what we
    # used to do when integration tests were enabled).
    if [ "$PLATFORM" = "vm" ]; then
        flutter test test/
    elif [ "$PLATFORM" = "chrome" ]; then
        flutter test --platform chrome test/
    else
        echo "unknown test platform"
        exit 1
    fi
elif [ "$BOT" = "test_dart2js" ]; then
    flutter pub get

    # TODO(https://github.com/flutter/flutter/issues/43538): Remove workaround.
    flutter build web --pwa-strategy=none --no-tree-shake-icons

    # TODO(https://github.com/flutter/devtools/issues/1987): once this issue is fixed,
    # we may need to explicitly exclude running integration_tests here (this is what we
    # used to do when integration tests were enabled).
    if [ "$PLATFORM" = "vm" ]; then
        WEBDEV_RELEASE=true flutter test test/
    elif [ "$PLATFORM" = "chrome" ]; then
        WEBDEV_RELEASE=true flutter test --platform chrome test/
    else
        echo "unknown test platform"
        exit 1
    fi
    echo $WEBDEV_RELEASE

elif [ "$BOT" = "integration_ddc" ]; then

    # Provision our packages.
    flutter pub get
    flutter config --enable-web

    # TODO(https://github.com/flutter/devtools/issues/1987): rewrite integration tests.
    # We need to run integration tests with -j1 to run with no concurrency.
    # flutter test -j1 test/integration_tests/

elif [ "$BOT" = "integration_dart2js" ]; then

    flutter pub get
    flutter config --enable-web

    # TODO(https://github.com/flutter/devtools/issues/1987): rewrite integration tests.
    # We need to run integration tests with -j1 to run with no concurrency.
    # WEBDEV_RELEASE=true flutter test -j1 test/integration_tests/

else

    echo "unknown bot configuration"
    exit 1

fi

popd
