#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Print out the Dart version in use.
dart --version

if [ "$USE_FLUTTER_SDK" = true ] ; then

    # Get Flutter.
    curl https://storage.googleapis.com/flutter_infra/releases/stable/macos/flutter_macos_v1.0.0-stable.zip -o flutter.zip
    unzip -qq flutter.zip
    ./flutter/bin/flutter config --no-analytics
    ./flutter/bin/flutter doctor
    export FLUTTER_SDK=`pwd`/flutter

    # Echo build info.
    echo $FLUTTER_SDK
    ./flutter/bin/flutter --version

    export PATH=./flutter/bin:./flutter/bin/cache/dart-sdk/bin:$PATH:~/.pub-cache/bin

    which dart

    # Analyze the source.
    pub global activate tuneup
    tuneup check --ignore-infos

    # Ensure we can build the app.
    pub global activate webdev
    webdev build

    # Run the tests.
    pub run test -t "useFlutterSdk"
    pub run test -t "useFlutterSdk" -pchrome-no-sandbox

else
    # Add globally activated packages to the path.
    export PATH="$PATH":~/.pub-cache/bin

    echo `which dart`

    # Analyze the source.
    pub global activate tuneup
    tuneup check --ignore-infos

    # Ensure we can build the app.
    pub global activate webdev
    webdev build

    # Run the tests.
    pub run test -x "useFlutterSdk"
    pub run test -x "useFlutterSdk" -pchrome-no-sandbox
fi
