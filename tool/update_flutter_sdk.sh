#!/bin/bash

# Copyright 2021 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

FLUTTER_DIR="`pwd`/flutter-sdk"
PATH="$FLUTTER_DIR/bin":$PATH

REQUIRED_FLUTTER_VERSION=$(<"flutter-version.txt")

if [ -d "$FLUTTER_DIR" ]; then 
  # switch to the specified version
  pushd flutter-sdk
  git fetch --tags
  git checkout $REQUIRED_FLUTTER_VERSION
  ./bin/flutter --version
  popd
else
  # clone the flutter repo and switch to the specified version
  git clone https://github.com/flutter/flutter flutter-sdk
  pushd flutter-sdk
  git checkout $REQUIRED_FLUTTER_VERSION
  ./bin/flutter --version
  popd
fi
