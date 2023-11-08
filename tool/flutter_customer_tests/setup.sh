#!/bin/bash -e
# Script to generate mocks for Devtools from the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

cd tool
flutter pub get
dart bin/devtools_tool generate-code --upgrade
cd ..
