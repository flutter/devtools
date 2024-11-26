#!/bin/bash -e
# Script to analyze the devtools repo for the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

# At this point we can expect that mocks have already been generated
# from the setup steps in
# https://github.com/flutter/tests/blob/main/registry/flutter_devtools.test

cd tool
flutter pub get

# We do not need to run `dart bin/dt.dart pub-get` here because
# the Flutter customer test retgistry script already runs 
# `flutter packages get` on the DevTools packages.

# Skip unimportant directories to speed up analysis.
# Unimportant directories are defined in tool/lib/commands/analyze.dart.
dart bin/dt.dart analyze --no-fatal-infos --skip-unimportant

cd ..
