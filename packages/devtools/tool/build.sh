# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

BUILD_OUTPUT="_release_package"

pushd "$(dirname "$0")/.."

pub global run webdev build --output web:$BUILD_OUTPUT/lib/build
cp pubspec.yaml $BUILD_OUTPUT
cp -R bin $BUILD_OUTPUT
pushd $BUILD_OUTPUT
pub get
popd

# TODO: The pubspec has all dependencies, but we only need args+http_server.

echo Build output is at `pwd`/$BUILD_OUTPUT.
echo
echo Test locally using
echo     pub global activate --source path `pwd`/$BUILD_OUTPUT
echo
echo Then publish that folder as the package.

popd
