# Script to execute smoke tests for the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

# At this point we can expect that mocks have already been generated from
# setup.sh, which is called from the setup steps in
# https://github.com/flutter/tests/blob/main/registry/flutter_devtools.test.

# Ensure test failures are reported.
set -e

# Test all tests in devtools_app_shared
cd packages/devtools_app_shared
flutter pub get
flutter test test/

cd ../devtools_app
flutter pub get
flutter test --tags=include-for-flutter-customer-tests test/
flutter test --exclude-tags=skip-for-flutter-customer-tests test/inspector/
flutter test --exclude-tags=skip-for-flutter-customer-tests test/inspector_v2/
flutter test --exclude-tags=skip-for-flutter-customer-tests test/shared/
