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

pushd packages/devtools_app

flutter clean
rm -rf build/web

flutter pub get

# Build a profile build rather than a release build to avoid minification
# as code size doesn't matter very much for us as minification makes some
# crashes harder to debug. For example, https://github.com/flutter/devtools/issues/2125

flutter build web \
  --pwa-strategy=none \
  --profile \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/ \
  --no-tree-shake-icons

# Delete the Flutter-generated service worker:
rm build/web/flutter_service_worker.js
# Rename the DevTools-specific service worker:
mv build/web/devtools_service_worker.js ../devtools/build/service_worker.js

# Ensure permissions are set correctly on canvaskit binaries.
chmod 0755 build/web/canvaskit/canvaskit.*
chmod 0755 build/web/canvaskit/profiling/canvaskit.*

popd

pushd packages/devtools
flutter pub get
popd
