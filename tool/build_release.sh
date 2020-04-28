#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x #echo on

pushd packages/devtools_app

rm -rf build
rm -rf ../devtools/build
flutter pub get
flutter pub run build_runner build -o web:build --release
mv ./build/packages ./build/pack

# move release to the devtools package from the devtools_app package for deployment
mv build ../devtools

# Build the flutter release of the app as well.

rm -rf build
flutter build web --dart-define=FLUTTER_WEB_USE_SKIA=true --no-tree-shake-icons
mkdir build/web/flutter
mv build/web/main.* build/web/flutter/

sed 's|main.dart.js|flutter\/main.dart.js|' build/web/index.html > build/web/tmp.html
sed 's|<head>|<head><style>.legacy-dart {visibility: hidden;}</style>|' build/web/tmp.html > build/web/flutter.html
rm build/web/index.html build/web/tmp.html

mv build/web/* ../devtools/build/

popd
