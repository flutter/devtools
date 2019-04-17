#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -e

pushd packages/devtools
echo `pwd`

# Print out the Dart version in use.
dart --version

# Add globally activated packages to the path.
export PATH=$PATH:~/.pub-cache/bin

# We should be using dart from /Users/travis/dart-sdk/bin/dart.
echo "which dart: " `which dart`

if [ "$BOT" = "main" ]; then

    # Provision our packages.
    pub get
    pub global activate webdev

    # Verify that dartfmt has been run.
    echo "Checking dartfmt..."

    if [[ $(dartfmt -n --set-exit-if-changed bin/ lib/ test/ web/) ]]; then
        echo "Failed dartfmt check: run dartfmt -w bin/ lib/ test/ web/"
        dartfmt -n --set-exit-if-changed bin/ lib/ test/ web/
        exit 1
    fi

    # Make sure the app versions are in sync.
    dart tool/version_check.dart

    # Analyze the source.
    pub global activate tuneup && tuneup check

    # Ensure we can build the app.
    pub run build_runner build -o web:build --release

elif [ "$BOT" = "test_ddc" ]; then

    # Provision our packages.
    pub get
    pub global activate webdev

    pub run test --reporter expanded --exclude-tags useFlutterSdk
    pub run test --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "test_dart2js" ]; then

    # Provision our packages.
    pub get
    pub global activate webdev

    WEBDEV_RELEASE=true pub run test --reporter expanded --exclude-tags useFlutterSdk
    WEBDEV_RELEASE=true pub run test --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "flutter_sdk_tests" ]; then

    # Get Flutter.
    if [ "$TRAVIS_DART_VERSION" = "stable" ]; then
        echo "Cloning stable Flutter branch"
        git clone https://github.com/flutter/flutter.git --branch stable ../flutter
    else
        echo "Cloning master Flutter branch"
        git clone https://github.com/flutter/flutter.git ../flutter
    fi
    cd ..
    export PATH=`pwd`/flutter/bin:`pwd`/flutter/bin/cache/dart-sdk/bin:$PATH
    flutter config --no-analytics
    flutter doctor

    # We should be using dart from ../flutter/bin/cache/dart-sdk/bin/dart.
    echo "which dart: " `which dart`

    # Return to the devtools directory.
    cd devtools

    # Provision our packages using Flutter's version of Dart.
    pub get
    pub global activate webdev

    # Run tests that require the Flutter SDK.
    pub run test -j1 --reporter expanded --tags useFlutterSdk

else

    echo "unknown bot configuration"
    exit 1

fi

popd
