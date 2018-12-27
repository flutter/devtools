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
which dart

# Analyze the source.
pub global activate tuneup
tuneup check --ignore-infos

# Ensure we can build the app.
pub global activate webdev
webdev build

if [ "$USE_FLUTTER_SDK" = true ] ; then
    # Get Flutter.
    curl https://storage.googleapis.com/flutter_infra/releases/stable/macos/flutter_macos_v1.0.0-stable.zip -o ../flutter.zip
    cd ..
    unzip -qq flutter.zip
    export PATH=`pwd`/flutter/bin:`pwd`/flutter/bin/cache/dart-sdk/bin:$PATH
    flutter config --no-analytics
    flutter doctor
    export FLUTTER_SDK=`pwd`/flutter

    # Echo build info.
    echo $FLUTTER_SDK

    # Should be using dart from ../flutter/bin/cache/dart-sdk/bin/dart
    which dart

    # Return to the devtools directory
    cd devtools

    echo `pwd`

    # Run the tests that require the Flutter SDK.
    pub run test -t "useFlutterSdk"
    # pub run test -t "useFlutterSdk" -pchrome-no-sandbox
else
    # Run the tests that do not require the Flutter SDK.
    pub run test -x "useFlutterSdk"
    pub run test -x "useFlutterSdk" -pchrome-no-sandbox
fi
