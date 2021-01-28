#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -ex #echo on

# This avoids requiring an internet connection for CanvasKit at runtime.
# This URL should be updated to keep in sync with the version from the engine.
# See https://github.com/flutter/engine/blob/353efcdf3c0ec0ecf0275d55e4a22329397f899f/lib/web_ui/lib/src/engine/canvaskit/initialization.dart#L51-L79,
# but compare with the code in master for getting the current version.
function download_canvaskit() {
  local canvaskit_url=https://unpkg.com/canvaskit-wasm@0.22.0/bin

  local flutter_bin=$(which flutter)
  local canvaskit_dart_file=$(dirname $flutter_bin)/cache/flutter_web_sdk/lib/_engine/engine/canvaskit/initialization.dart
  if ! grep -q "defaultValue: \'$canvaskit_url" "$canvaskit_dart_file"; then
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
  --dart-define=FLUTTER_WEB_USE_EXPERIMENTAL_CANVAS_TEXT=true \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=assets/canvaskit/ \
  --no-tree-shake-icons

cp build/web/main.dart.js build/web/main_fallback.dart.js

flutter build web \
  --pwa-strategy=none \
  --profile \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=assets/canvaskit/ \
  --no-tree-shake-icons

mv build/web ../devtools/build

popd
