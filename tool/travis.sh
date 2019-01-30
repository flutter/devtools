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

# Should be using dart from /Users/travis/dart-sdk/bin/dart
echo "which dart: " `which dart`

pub get

# Ensure we can build the app.
pub run webdev build

if [ "$BOT" = "main" ]; then

    # Analyze the source.
    pub global activate tuneup
    tuneup check

    # Verify that dartfmt has been run.
    echo "Checking dartfmt..."
    if [[ $(dartfmt -n --set-exit-if-changed web/ lib/ test/) ]]; then
        echo "Failed dartfmt check: run dartfmt -w bin/ lib/ test/"
        exit 1
    fi

elif [ "$BOT" = "test_ddc" ]; then

    pub run test --reporter expanded --exclude-tags useFlutterSdk
    pub run test --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "test_dart2js" ]; then

    WEBDEV_RELEASE=true pub run test --reporter expanded --exclude-tags useFlutterSdk
    WEBDEV_RELEASE=true pub run test --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "test_flutter" ]; then

    # Get Flutter.
    git clone https://github.com/flutter/flutter.git ../flutter
    cd ..
    export PATH=`pwd`/flutter/bin:`pwd`/flutter/bin/cache/dart-sdk/bin:$PATH
    flutter config --no-analytics
    flutter doctor

    # Should be using dart from ../flutter/bin/cache/dart-sdk/bin/dart
    echo "which dart: " `which dart`

    # Return to the devtools directory
    cd devtools

    # Run tests that require the Flutter SDK.
    pub run test --reporter expanded --tags useFlutterSdk

else

    echo "unknown bot configuration"
    exit 1

fi

popd
