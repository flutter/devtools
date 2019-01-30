#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Print out the Dart version in use.
dart --version

# Add globally activated packages to the path.
export PATH=$PATH:~/.pub-cache/bin

# Should be using dart from /Users/travis/dart-sdk/bin/dart
echo "which dart: " `which dart`

# Analyze the source.
pub global activate tuneup
tuneup check

# Ensure we can build the app.
pub run webdev build

if [ "$BOT" = "main" ]; then

    # Run tests that do not require the Flutter SDK.
    pub run test --reporter expanded --exclude-tags useFlutterSdk
    pub run test --reporter expanded --exclude-tags useFlutterSdk --platform chrome-no-sandbox

elif [ "$BOT" = "flutter" ]; then

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

    # Chrome test passes locally but fails on Travis. See example failure:
    # https://travis-ci.org/flutter/devtools/jobs/472755560.
    # TODO: investigate if we have a need to run tests requiring the Flutter SDK on Chrome.
    # pub run test --reporter expanded --tags useFlutterSdk --platform chrome-no-sandbox

else

    echo "unknown bot configuration"
    exit 1

fi
