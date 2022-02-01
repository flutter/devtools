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
echo "Cloning the Flutter $PINNED_FLUTTER_CHANNEL branch"
git clone https://github.com/flutter/flutter.git --branch $PINNED_FLUTTER_CHANNEL ./flutter-sdk

# Look in the dart bin dir first, then the flutter one, then the one for the
# devtools repo. We don't use the dart script from flutter/bin as that script
# can and does print 'Waiting for another flutter command...' at inopportune
# times.
export PATH=`pwd`/flutter-sdk/bin/cache/dart-sdk/bin:`pwd`/flutter-sdk/bin:`pwd`/bin:$PATH

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

# Put the Flutter version into a variable.
# First awk extracts "Flutter x.y.z-pre.a":
#   -F '•'         uses the bullet as field separator
#   NR==1          says only take the first record (line)
#   { print $1}    prints just the first field
# Second awk splits on space (default) and takes the second field (the version)
export FLUTTER_VERSION=$(flutter --version | awk -F '•' 'NR==1{print $1}' | awk '{print $2}')
echo "Flutter version is '$FLUTTER_VERSION'"

echo "Testing with the Flutter test environment: $FLUTTER_TEST_ENV"

if [ "$FLUTTER_TEST_ENV" = "pinned" ]; then
  export DART_DEFINE_ARGS=""
else
  export DART_DEFINE_ARGS="--dart-define=FLUTTER_BRANCH=$FLUTTER_TEST_ENV"
fi

echo "Flutter tests will be ran with args: $DART_DEFINE_ARGS"

# Some integration tests assume the devtools package is up to date and located
# adjacent to the devtools_app package.
pushd packages/devtools
    # We want to make sure that devtools is retrievable with regular pub.
    flutter pub get
popd

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

    # Analyze the source.
    dart analyze --fatal-infos

    # Ensure we can build the app.
    flutter pub run build_runner build -o web:build --release

elif [ "$BOT" = "test_ddc" ]; then

    flutter pub get

    # TODO(https://github.com/flutter/flutter/issues/43538): Remove workaround.
    flutter config --enable-web
    flutter build web --pwa-strategy=none --no-tree-shake-icons

    # Run every test except for integration_tests.
    # The flutter tool doesn't support excluding a specific set of targets,
    # so we explicitly provide them.
    if [ "$PLATFORM" = "vm" ]; then
        flutter test $DART_DEFINE_ARGS test/*.dart test/fixtures/
    elif [ "$PLATFORM" = "chrome" ]; then
        flutter test --platform chrome $DART_DEFINE_ARGS test/*.dart test/fixtures/
    else
        echo "unknown test platform"
        exit 1
    fi
elif [ "$BOT" = "test_dart2js" ]; then
    flutter pub get

    # TODO(https://github.com/flutter/flutter/issues/43538): Remove workaround.
    flutter config --enable-web
    flutter build web --pwa-strategy=none --no-tree-shake-icons

    # Run every test except for integration_tests.
    # The flutter tool doesn't support excluding a specific set of targets,
    # so we explicitly provide them.
    if [ "$PLATFORM" = "vm" ]; then
        WEBDEV_RELEASE=true flutter test $DART_DEFINE_ARGS test/*.dart test/fixtures/
    elif [ "$PLATFORM" = "chrome" ]; then
        WEBDEV_RELEASE=true flutter test --platform chrome $DART_DEFINE_ARGS test/*.dart test/fixtures/
    else
        echo "unknown test platform"
        exit 1
    fi
    echo $WEBDEV_RELEASE

elif [ "$BOT" = "integration_ddc" ]; then

    # Provision our packages.
    flutter pub get
    flutter config --enable-web

    # We need to run integration tests with -j1 to run with no concurrency.
    flutter test -j1 $DART_DEFINE_ARGS test/integration_tests/

    flutter test -j1 $DART_DEFINE_ARGS test/integration/

elif [ "$BOT" = "integration_dart2js" ]; then

    flutter pub get
    flutter config --enable-web

    # We need to run integration tests with -j1 to run with no concurrency.
    WEBDEV_RELEASE=true flutter test -j1 $DART_DEFINE_ARGS test/integration_tests/ test/integration/

elif [ "$BOT" = "packages" ]; then

    popd

    # Get packages
    repo_tool packages-get

    # Analyze the code
    repo_tool analyze

    pushd packages/devtools_app

else

    echo "unknown bot configuration"
    exit 1

fi

popd
