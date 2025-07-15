<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
# Instructions for running a DevTools integration test

## Set up ChromeDriver (one time only)

1. Follow the instructions
   [here](https://flutter.dev/to/integration-test-on-web) to download
   ChromeDriver.

2. Add `chromedriver` to your PATH by modifying your `.bash_profile` or
   `.zshrc`:

   ```
   export PATH=${PATH}:/Users/me/folder_containing_chromedriver/
   ```

3. Verify you can start `chromedriver`:

   ```
   chromedriver --port=4444
   ```

   If you get the error "'chromedriver' cannot be opened because it is from an
   unidentified developer." on MacOS, run the following command with your path
   to the `chromedriver` executable:

   ```
   xattr -d com.apple.quarantine ~/path/to/chromedriver
   ```

### Updating ChromeDriver

If you update your Chrome version (or it updates automatically), you may need to
update your `chromedriver` executable as well. To do this, delete your existing
`chromedriver` executable (you can find this by running `which chromedriver`).
Then, download the proper `chromedriver` zip file from
[here](https://googlechromelabs.github.io/chrome-for-testing/#stable) based on
your platform. Copy the link for your platform, open in a new tab, and then the
zip file will be downloaded. Unzip the folder, and move the executable to the
same location that you just deleted the previous executable from.

If you are on MacOS, you will likely need to run this command again on the new
executable:

```
xattr -d com.apple.quarantine ~/path/to/chromedriver
```

## Running a test

* To run all integration tets: `dart run integration_test/run_tests.dart`
* To run a single integration test:
  `dart run integration_test/run_tests.dart --target=integration_test/test/my_test.dart`

### Special flags:

* `--test-app-uri`: to speed up local development, you can pass in a VM service
  URI from a Dart or Flutter app running on your local machine. This saves the
  cost of spinning up a new test app for each test run. To do this, pass the VM
  service URI using the `--test-app-uri=some-uri` run flag.
* `--headless`: this will run the integration test on the 'web-server' device
  instead of the 'chrome' device, meaning you will not be able to see the
  integration test run in Chrome when running locally.
* `--update-goldens`: behaves like the `--update-goldens` flag for Flutter unit
  tests, updating the golden images to the results produced by the test run.

# Where to add an integration test

Where you should place your integration test will depend on the answers to the
following questions:

1. Does your test require DevTools to be connected to a live test application?
   This is a ["live connection"](#live-connection-integration-tests) integration
   test.
2. Does your test need to use offline (and stable) test data? This is an
   ["offline"](#offline-integration-tests) integration test.

## "live connection" integration tests

Tests under `integration_test/test/live_connection` will:
* run a "test app" (a Dart application or a Flutter app), and
* run DevTools, connecting it to that test app.

## "offline" integration tests

Tests under `integration_test/test/offline` will run DevTools without connecting
it to a live application. Integration tests in this directory will load offline
data for testing. This is useful for testing features that will not have stable
data from a live application. For example, the Performance screen timeline data
will never be stable with a live applicaiton, so loading offline data allows for
screenshot testing without flakiness.

# In-file test arguments

Some test arguments are set in the test file directly as specifically formatted
comments.

For example:
```dart
// Do not delete these arguments. They are parsed by test runner.
// test-argument:appPath="test/test_infra/fixtures/memory_app"
// test-argument:experimentsOn=true
```

For a list of such arguments, see
[_in_file_args.dart](test_infra/run/_in_file_args.dart). For an example of
usage, see
[eval_and_browse_test.dart](test/live_connection/eval_and_browse_test.dart).

# Debugging

There is not an easy setup for debugging a DevTools integration test from an
IDE. But print debugging can be applied as follows:

* In the test code, (the "target" of the integration test command), `print` or
  [`logStatus`][] will print to the terminal.
* In the "test app," there is no acccess to any `print`ed output. If the app
  has access to `dart:io`, you can still log to a file, as easy as
  `io.File('some-file.txt').writeAsStringSync('...');`.


[`logStatus`]: https://github.com/flutter/devtools/blob/master/packages/devtools_test/lib/src/helpers/utils.dart#L243
