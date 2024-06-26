The scripts in this directory are used in the Flutter customer test registry
[test](https://github.com/flutter/tests/blob/main/registry/flutter_devtools.test)
for DevTools.

If a test is flaky or needs to be skipped on the Flutter customer test run,
skip the test case by adding the tag 'skip-for-flutter-customer-tests', which
is defined in a const in
[utils.dart](https://github.com/flutter/devtools/blob/master/packages/devtools_test/lib/src/helpers/utils.dart#L15)
inside the `devtools_test` package.
