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

flutter precache --web

# Provision the canvaskit assets.

# This avoids requiring an internet connection for CanvasKit at runtime. This
# URL should be updated to keep in sync with the version from the engine. See
# https://github.com/flutter/engine/blob/master/lib/web_ui/lib/src/engine/canvaskit/initialization.dart#L50-L78,
# but compare with the code in master for getting the current version. A better
# solution would be to either upstream this functionality into the
# flutter_tools, (https://github.com/flutter/flutter/issues/70101), or to read
# this from a manifest provided (https://github.com/flutter/flutter/issues/74934).

canvaskit_url=https://unpkg.com/canvaskit-wasm@0.28.1/bin/

flutter_bin=$(which flutter)
canvaskit_dart_file=$(dirname $flutter_bin)/cache/flutter_web_sdk/lib/_engine/engine/canvaskit/initialization.dart
if ! grep -q "defaultValue: '$canvaskit_url'" "$canvaskit_dart_file"; then
  echo "CanvasKit $canvaskit_url does not match local web engine copy. Please update before continuing."
  exit -1
fi

curl $canvaskit_url/canvaskit.js \
  -o packages/devtools_app/assets/canvaskit/canvaskit.js
curl $canvaskit_url/canvaskit.wasm \
  -o packages/devtools_app/assets/canvaskit/canvaskit.wasm
curl $canvaskit_url/profiling/canvaskit.js \
  -o packages/devtools_app/assets/canvaskit/profiling/canvaskit.js
curl $canvaskit_url/profiling/canvaskit.wasm \
  -o packages/devtools_app/assets/canvaskit/profiling/canvaskit.wasm
