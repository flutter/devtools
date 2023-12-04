#!/bin/bash -e
# Script to generate mocks for Devtools from the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

root_dir=$(pwd)
tool_dir="$root_dir/tool/bin"
export PATH=$PATH:$tool_dir
# Force devtools_tool to use the current Flutter (which is available on PATH).
export DEVTOOLS_TOOL_FLUTTER_FROM_PATH=true
cd tool
flutter pub get
devtools_tool pub-get
devtools_tool generate-code --upgrade
cd ..
