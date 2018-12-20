#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
set -e

# Print out the Dart version in use.
dart --version

# Get Flutter.
curl https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_v1.0.0-stable.tar.xz -o ../flutter.tar.xz
ls -la | grep flutter.tar.xz
tar -xzf flutter.tar.xz
export PATH="$PATH":`pwd`/../flutter/bin:`pwd`/../flutter/bin/cache/dart-sdk/bin
flutter config --no-analytics
flutter doctor
export FLUTTER_SDK=`pwd`/../flutter

# Echo build info.
echo $FLUTTER_SDK
flutter --version

# Add globally activated packages to the path.
export PATH="$PATH":"~/.pub-cache/bin"

# Analyze the source.
pub global activate tuneup
tuneup check --ignore-infos

# Ensure we can build the app.
pub global activate webdev
webdev build

# Run the tests.
pub run test
pub run test -pchrome-no-sandbox
