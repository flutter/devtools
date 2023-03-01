#!/bin/bash

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
  ./update_flutter_sdk.sh
fi

popd

# echo on
set -ex

echo "Flutter Path: $(which flutter)"
echo "Flutter Version: $(flutter --version)"

if [[ $1 = "--update-perfetto" ]]; then
  $TOOL_DIR/update_perfetto.sh
fi

pushd $DEVTOOLS_DIR/packages/devtools_app

flutter clean
rm -rf build/web

flutter pub get

# Build a profile build rather than a release build to avoid minification
# as code size doesn't matter very much for us as minification makes some
# crashes harder to debug. For example, https://github.com/flutter/devtools/issues/2125

# TODO(https://github.com/flutter/devtools/issues/5148): remove the FLUTTER_WEB_CANVASKIT_URL
# flag and set `canvasKitBaseUrl` in `initializeEngine` instead.
# See https://docs.flutter.dev/development/platform-integration/web/initialization.

flutter build web \
  --web-renderer canvaskit \
  --pwa-strategy=none \
  --release \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/ \
  --no-tree-shake-icons

# Ensure permissions are set correctly on canvaskit binaries.
chmod 0755 build/web/canvaskit/canvaskit.*

popd
