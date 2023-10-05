# Script to execute integration tests for the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

# At this point we can expect that mocks have already been generated
# from the setup steps in
# https://github.com/flutter/tests/blob/main/registry/flutter_devtools.test

cd packages/devtools_app
flutter pub get

# Run the integration test that builds every DevTools screen. 
dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/app_test.dart
