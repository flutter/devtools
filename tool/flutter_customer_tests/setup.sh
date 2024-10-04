#!/bin/bash -e
# Script to generate mocks for Devtools from the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

root_dir=$(pwd)
tool_dir="$root_dir/tool/bin"
export PATH=$PATH:$tool_dir
# Force dt to use the current Flutter (which is available on PATH).
export DEVTOOLS_TOOL_FLUTTER_FROM_PATH=true
cd tool
flutter pub get
dt pub-get
dt generate-code --upgrade
cd ..
