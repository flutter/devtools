# Script to analyze the devtools repo for the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

cd tool
flutter pub get
dart bin/devtools_tool.dart analyze
cd ..
