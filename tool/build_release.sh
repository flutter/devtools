#!/bin/bash

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

set -x #echo on

pushd packages/devtools_app

rm -rf build
rm -rf ../devtools/build
flutter pub get

flutter build web --dart-define=FLUTTER_WEB_USE_SKIA=true --no-tree-shake-icons
mv build/web ../devtools/build

popd
