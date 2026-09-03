#!/bin/bash

# Copyright 2023 The Flutter Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

# Fast fail the script on failures.
set -ex

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export DEVTOOLS_DIR=$SCRIPT_DIR/../..

# In GitBash on Windows, we have to call flutter.bat so we alias them in this
# script to call the correct one based on the OS.
function flutter {
    if [[ $RUNNER_OS == "Windows" ]]; then
        command flutter.bat "$@"
    else
        command flutter "$@"
    fi
}
export -f flutter

# Determine the Flutter SDK to use:
# * If `DEVTOOLS_TOOL_FLUTTER_FROM_PATH` is "true", then discover from `PATH`.
# * If `./tool/flutter-sdk` (a directory) exists, then use that.
if [ "$DEVTOOLS_TOOL_FLUTTER_FROM_PATH" = "true" ]; then
    if command -v flutter &> /dev/null; then
        FLUTTER_EXE="$(command -v flutter)"
    elif command -v flutter.bat &> /dev/null; then
        FLUTTER_EXE="$(command -v flutter.bat)"
    else
        echo "DEVTOOLS_TOOL_FLUTTER_FROM_PATH is set to true, but flutter was not found on PATH"
        exit 1
    fi
    FLUTTER_BIN="$(cd "$(dirname "$FLUTTER_EXE")" && pwd -P)"
    FLUTTER_DIR="$(cd "$FLUTTER_BIN/.." && pwd -P)"
    echo "Using Flutter from PATH at: $FLUTTER_DIR"
    export DEVTOOLS_TOOL_FLUTTER_FROM_PATH=true
elif [ -d "./tool/flutter-sdk" ]; then
    FLUTTER_DIR="$(pwd)/tool/flutter-sdk"
else
    echo "Expected ./tool/flutter-sdk to exist, or DEVTOOLS_TOOL_FLUTTER_FROM_PATH to be set to true"
    exit 1
fi

# Look in the dart bin/ directory first, then the flutter one, then the one for
# the devtools repo. We don't use the dart script from 'flutter/bin' as that
# script can and does print 'Waiting for another flutter command...' at
# inopportune times.
export PATH="$FLUTTER_DIR/bin/cache/dart-sdk/bin:$FLUTTER_DIR/bin:`pwd`/bin:$PATH"

# Look up the latest flutter candidate (this is the latest flutter version in g3)
# TODO(https://github.com/flutter/devtools/issues/4591): re-write this script as a
# shell script so we won't have to incurr the cost of building flutter tool twice.

flutter config --no-analytics
flutter doctor

# We should be using dart from the Flutter SDK's cache/dart-sdk/bin/ directory.
echo "which flutter: " `which flutter`
echo "which dart: " `which dart`

# Disable analytics to ensure that the welcome message for the dart cli tooling
# doesn't interrupt the CI bots.
dart --disable-analytics

# Print out the versions and ensure we can call Dart, Pub, and Flutter.
flutter --version
dart --version

# Fetch dependencies for the tool/ directory
pushd $DEVTOOLS_DIR/tool
flutter pub get
popd

# Ensure the dt command is available
export PATH="$PATH":"$DEVTOOLS_DIR/tool/bin"

# Fetch dependencies
dt pub-get --only-main

# Generate code.
dt generate-code
