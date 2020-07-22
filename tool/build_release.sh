#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x #echo on

pushd packages/devtools_app

rm -rf build
rm -rf ../devtools/build
flutter pub get

# Build a profile build rather than a release build to avoid minification
# as code size doesn't matter very much for us as minification makes some
# crashes harder to debug. For example, https://github.com/flutter/devtools/issues/2125

flutter build web --profile --dart-define=FLUTTER_WEB_USE_EXPERIMENTAL_CANVAS_TEXT=true --no-tree-shake-icons
cp build/web/main.dart.js build/web/main_fallback.dart.js
flutter build web --profile --dart-define=FLUTTER_WEB_USE_SKIA=true --no-tree-shake-icons
mv build/web ../devtools/build

popd
