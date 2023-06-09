# Script to execute smoke tests for the flutter/tests registry
# https://github.com/flutter/tests
# This is executed as a pre-submit check for every PR in flutter/flutter

# Generate mocks for tests
# flutter/tests does not allow output from execution.
./tool/generate_code.sh >> output.txt

# Test devtools_shared
# pushd packages/devtools_shared
# flutter test test/
# popd

# Test devtools_app
pushd packages/devtools_app
flutter test test/inspector/
popd
