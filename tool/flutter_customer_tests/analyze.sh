#!/bin/bash -e
# Script to analyze the devtools repo for the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

which dart
dart --version
which flutter
flutter --version

cd tool
flutter pub get
dart bin/devtools_tool.dart pub-get
dart bin/devtools_tool.dart analyze
cd ..
