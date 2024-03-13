#!/bin/bash

# TODO(kenz): delete this script once we can confirm it is not used in the
# Dart SDK or in infra tooling.

# Copyright 2019 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Contains a path to this script, relative to the directory it was called from.
RELATIVE_PATH_TO_SCRIPT="${BASH_SOURCE[0]}"

# The directory that this script is located in.
TOOL_DIR=`dirname "${RELATIVE_PATH_TO_SCRIPT}"`

# The devtools root directory is assumed to be the parent of this directory.
DEVTOOLS_DIR="${TOOL_DIR}/.."

pushd $TOOL_DIR

if [[ $1 = "--no-update-flutter" ]]
then
  # Use the Flutter SDK that is already on the user's PATH.
  FLUTTER_EXE=`which flutter`
  echo "Using the Flutter SDK that is already on PATH: $FLUTTER_EXE"
else
  # Use the Flutter SDK from flutter-sdk/.
  FLUTTER_DIR="`pwd`/flutter-sdk"
  PATH="$FLUTTER_DIR/bin":$PATH

  # Make sure the flutter sdk is on the correct branch.
  devtools_tool update-flutter-sdk
fi

popd

# echo on
set -ex

echo "Flutter Path: $(which flutter)"
echo "Flutter Version: $(flutter --version)"

if [[ $1 = "--update-perfetto" ]]; then
  devtools_tool update-perfetto
fi

pushd $DEVTOOLS_DIR/packages/devtools_shared
flutter pub get
popd

pushd $DEVTOOLS_DIR/packages/devtools_extensions
flutter pub get
popd

pushd $DEVTOOLS_DIR/packages/devtools_app

flutter clean
rm -rf build/web

flutter pub get

flutter build web \
  --web-renderer canvaskit \
  --pwa-strategy=offline-first \
  --dart2js-optimization=O1 \
  --release \
  --no-tree-shake-icons

# Ensure permissions are set correctly on canvaskit binaries.
chmod 0755 build/web/canvaskit/canvaskit.*

popd
