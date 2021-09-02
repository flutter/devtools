#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Use the Flutter SDK from flutter-sdk/.
FLUTTER_DIR="`pwd`/flutter-sdk"
PATH="$FLUTTER_DIR/bin":$PATH

REQUIRED_FLUTTER_VERSION=$(<"flutter-version.txt")

flutter --version
ACTUAL_FLUTTER_VERSION=$(<"$FLUTTER_DIR/version")

# Check that the 'actual' and 'required' SDK versions agree.
if [[ "$REQUIRED_FLUTTER_VERSION" != "$ACTUAL_FLUTTER_VERSION" ]]; then
  echo ""
  echo "flutter-version.txt != flutter-sdk/version"
  echo "  $REQUIRED_FLUTTER_VERSION != $ACTUAL_FLUTTER_VERSION"
  echo ""
  echo "To switch versions, run './tool/update_flutter_sdk.sh'."
  exit 1
fi

# echo on
set -ex

# This avoids requiring an internet connection for CanvasKit at runtime.
# This URL should be updated to keep in sync with the version from the engine.
# See https://github.com/flutter/engine/blob/master/lib/web_ui/lib/src/engine/canvaskit/initialization.dart#L50-L78,
# but compare with the code in master for getting the current version.
# A better solution would be to either upstream this functionality into the flutter_tools,
# (https://github.com/flutter/flutter/issues/70101), or to read this from a manifest 
# provided (https://github.com/flutter/flutter/issues/74934).
function download_canvaskit() {
  local canvaskit_url=https://unpkg.com/canvaskit-wasm@0.28.1/bin/

  flutter precache --web

  local flutter_bin=$(which flutter)
  local canvaskit_dart_file=$(dirname $flutter_bin)/cache/flutter_web_sdk/lib/_engine/engine/canvaskit/initialization.dart
  if ! grep -q "defaultValue: '$canvaskit_url'" "$canvaskit_dart_file"; then
    echo "CanvasKit $canvaskit_url does not match local web engine copy. Please update before continuing."
    exit -1
  fi

  mkdir -p build/web/assets/canvaskit/profiling

  curl $canvaskit_url/canvaskit.js -o build/web/assets/canvaskit/canvaskit.js
  curl $canvaskit_url/canvaskit.wasm -o build/web/assets/canvaskit/canvaskit.wasm
  curl $canvaskit_url/profiling/canvaskit.js -o build/web/assets/canvaskit/profiling/canvaskit.js
  curl $canvaskit_url/profiling/canvaskit.wasm -o build/web/assets/canvaskit/profiling/canvaskit.wasm
}

pushd packages/devtools_app

rm -rf build
rm -rf ../devtools/build

download_canvaskit

flutter pub get

# Build a profile build rather than a release build to avoid minification
# as code size doesn't matter very much for us as minification makes some
# crashes harder to debug. For example, https://github.com/flutter/devtools/issues/2125

flutter build web \
  --pwa-strategy=none \
  --profile \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=assets/canvaskit/ \
  --no-tree-shake-icons

mv build/web ../devtools/build

popd

pushd packages/devtools
flutter pub get
popd
