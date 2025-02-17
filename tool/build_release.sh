#!/bin/bash

# TODO(kenz): delete this script once we can confirm it is not used in the
# Dart SDK or in infra tooling.

# Copyright 2025 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
  FLUTTER_EXE="$(which flutter)"
  echo "Using the Flutter SDK that is already on PATH: $FLUTTER_EXE"
  FLUTTER_DIR="$(dirname "$(dirname "$FLUTTER_EXE")")"
else
  # Use the Flutter SDK from flutter-sdk/.
  FLUTTER_DIR="`pwd`/flutter-sdk"
  PATH="$FLUTTER_DIR/bin":$PATH

  # Make sure the flutter sdk is on the correct branch.
  dt update-flutter-sdk
fi

popd

# echo on
set -eux

# TODO(fujino): delete once https://github.com/flutter/flutter/issues/142521
# is resolved.
pushd "$FLUTTER_DIR"
  # If we've already written the wrong version number to disk, delete it
  rm -f bin/cache/flutter.version.json
  # The flutter tool relies on git tags to determine its version
  git fetch https://github.com/flutter/flutter.git --tags -f
  git describe --tags
  # Print out local tags for debugging
  git tag -l
popd

echo "Flutter Path: $(which flutter)"
echo "Flutter Version: $(flutter --version)"

# TODO(https://github.com/flutter/flutter/issues/154194): remove this.
echo "Running flutter --help as a workaround for https://github.com/flutter/flutter/issues/154194"
flutter --help

if [[ $1 = "--update-perfetto" ]]; then
  dt update-perfetto
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
  --source-maps \
  --wasm \
  --pwa-strategy=offline-first \
  --release \
  --no-tree-shake-icons

# Ensure permissions are set correctly on canvaskit binaries.
chmod 0755 build/web/canvaskit/canvaskit.*

popd
