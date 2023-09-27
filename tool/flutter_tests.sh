# Script to execute smoke tests for the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

# Generate mocks for tests
# flutter/tests does not allow output from execution.
./tool/generate_code.sh >> output.txt

# Test all tests in devtools_app_shared
# flutter pub get
# cd packages/devtools_app_shared
# flutter test test/

# Test only tests in devtools_app with the 'flutterTestRegistry' tag
cd packages/devtools_app
flutter pub get
flutter test test/ -t flutterTestRegistry

# Run the integration test that builds every DevTools screen. 
# dart run integration_test/run_tests.dart --target=integration_test/test/live_connection/app_test.dart