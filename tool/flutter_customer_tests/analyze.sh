#!/bin/bash -e
# Script to analyze the devtools repo for the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

# At this point we can expect that mocks have already been generated
# from the setup steps in
# https://github.com/flutter/tests/blob/main/registry/flutter_devtools.test

cd tool
flutter pub get
dart bin/devtools_tool.dart pub-get
dart bin/devtools_tool.dart analyze --no-fatal-infos
cd ..
