#!/bin/bash

# Copyright 2018 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Fast fail the script on failures.
#set -e

# Print out the Dart version in use.
dart --version

# Add globally activated packages to the path.
export PATH="$PATH":"~/.pub-cache/bin"

# Analyze the source.
pub global activate tuneup
tuneup check --ignore-infos

# Ensure we can build the app.
pub global activate webdev
webdev build

# Run the tests
pub run test
pub run test -pchrome
