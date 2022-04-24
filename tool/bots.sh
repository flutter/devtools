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

if [ "$FLUTTER_TEST_ENV" = "pinned" ]; then
  export DART_DEFINE_ARGS="--dart-define=SHOULD_TEST_GOLDENS=true"
else
  echo "Cloning the Flutter $FLUTTER_TEST_ENV branch to use for test apps"
  git clone https://github.com/flutter/flutter.git --branch $FLUTTER_TEST_ENV ./flutter-sdk-$FLUTTER_TEST_ENV
  export DART_DEFINE_ARGS="--dart-define=SHOULD_TEST_GOLDENS=false --dart-define=FLUTTER_CMD=`pwd`/flutter-sdk-$FLUTTER_TEST_ENV/bin/flutter"
fi

echo "Testing with Flutter test environment: $FLUTTER_TEST_ENV"
echo "Flutter tests will be ran with args: $DART_DEFINE_ARGS"

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

# Generate code.
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

    # Analyze the source.
    dart analyze --fatal-infos

    # Ensure we can build the app.
    flutter build web --release

    # Test the devtools_shared package tests on the main bot.
    popd
    pushd packages/devtools_shared
    echo `pwd`

    flutter test test/ --no-sound-null-safety
    popd

    # Change the directory back to devtools_app.
    pushd packages/devtools_app
    echo `pwd`

elif [ "$BOT" = "test_ddc" ]; then

    # Provision our packages.
    flutter pub get

    # TODO(https://github.com/flutter/flutter/issues/43538): Remove workaround.
    flutter config --enable-web
    flutter build web --pwa-strategy=none --no-tree-shake-icons

    # Run every test except for integration_tests.
    # The flutter tool doesn't support excluding a specific set of targets,
    # so we explicitly provide them.
    if [ "$PLATFORM" = "vm" ]; then
        flutter test $DART_DEFINE_ARGS test/*.dart test/fixtures/ --no-sound-null-safety

        # We are in process of transforming from unsound null safety to sound one.
        # At the moment some tests fail without the flag --no-sound-null-safety.
        # We are fixing them one by one and adding to the list below. After all
        # tests are fixed, we will delete this list and remove the flags from the commands.

        flutter test $DART_DEFINE_ARGS \
          test/chart_test.dart \
          test/cpu_profiler_controller_test.dart \
          test/cpu_profiler_test.dart \
          test/debugger_console_test.dart \
          test/debugger_controller_test.dart \
          test/debugger_controller_stdio_test.dart \
          test/debugger_floating_test.dart \
          test/device_dialog_test.dart \
          test/enhance_tracing_test.dart \
          test/logging_controller_test.dart \
          test/logging_screen_data_test.dart \
          test/logging_screen_test.dart \
          test/performance_controller_test.dart \
          test/performance_screen_test.dart \
          test/profiler_screen_controller_test.dart \
          test/profiler_screen_test.dart \
          test/timeline_analysis_test.dart

    elif [ "$PLATFORM" = "chrome" ]; then
        flutter test --platform chrome $DART_DEFINE_ARGS test/*.dart test/fixtures/ --no-sound-null-safety
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
        WEBDEV_RELEASE=true flutter test $DART_DEFINE_ARGS test/*.dart test/fixtures/ --no-sound-null-safety
    elif [ "$PLATFORM" = "chrome" ]; then
        WEBDEV_RELEASE=true flutter test --platform chrome $DART_DEFINE_ARGS test/*.dart test/fixtures/ --no-sound-null-safety
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
    # flutter test -j1 $DART_DEFINE_ARGS test/integration_tests/

elif [ "$BOT" = "integration_dart2js" ]; then

    flutter pub get
    flutter config --enable-web

    # TODO(https://github.com/flutter/devtools/issues/1987): rewrite integration tests.
    # We need to run integration tests with -j1 to run with no concurrency.
    # WEBDEV_RELEASE=true flutter test -j1 $DART_DEFINE_ARGS test/integration_tests/

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
