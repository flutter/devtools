# Instructions for running a DevTools integration test

## Set up ChromeDriver (one time only)

1. Follow the instructions [here](https://docs.flutter.dev/cookbook/testing/integration/introduction#5b-web) to download ChromeDriver.

2. Add `chromedriver` to your PATH by modifying your `.bash_profile` or `.zshrc`:

```
export PATH=${PATH}:/Users/me/folder_containing_chromedriver/
```

3. Verify you can start `chromedriver`:

```
chromedriver --port=4444
```

If you get the error "'chromedriver' cannot be opened because it is from an unidentified developer.", run the following command with your path to the `chromedriver` executable:

```
xattr -d com.apple.quarantine ~/path/to/chromedriver
```

## Running a test

* To run all integration tets: `dart run integration_test/run_tests.dart`
* To run a single integration test: `dart run integration_test/run_tests.dart --target=integration_test/test/my_test.dart`

### Special flags:

* `--test-app-uri`: to speed up local development, you can pass in a vm service uri from a Dart or Flutter
app running on your local machine. This saves the cost of spinning up a new test app for each test run. To
do this, pass the vm service uri using the `--test-app-uri=some-uri` run flag.
* `--headless`: this will run the integration test on the 'web-server' device instead of the 'chrome' device, meaning you will not be able to see the integration test run in Chrome when running locally.
* `--update-goldens`: behaves like the `--update-goldens` flag for Flutter unit tests,
updating the golden images to the results produced by the test run.

The following flags are available, but should not be used manually. To run a test with offline data
or with experiments enabled, place the test in the proper directory, and the `run_tests.dart` script
will propagate the proper flag values automatically (see [instructions below](#where-to-add-an-integration-test))

* `--offline`: indicates that we do not need to start a test app to run this test. This will take precedence
if both --offline and --test-app-uri are present.
* `--enable_experiments`: enables experiments for DevTools within the integration test environment

# Where to add an integration test

Where you should place your integration test will depend on the answers to the following questions:
1. Does your test require DevTools to be connected to a live test application? This is a
["live connection"](#live-connection-integration-tests) integration test.
2. Does your test need to use offline (and stable) test data? This is an
["offline"](#offline-integration-tests) integration test.

## "live connection" integration tests

Tests under `integration_test/test/live_connection` will run DevTools and connect it to a live Dart or Flutter
application.

## "offline" integration tests

Tests under `integration_test/test/offline` will run DevTools without connecting it to a live application.
Integration tests in this directory will load offline data for testing. This is useful
for testing features that will not have stable data from a live application. For example,
the Performance screen timeline data will never be stable with a live applicaiton, so
loading offline data allows for screenshot testing without flakiness.

# In-file test arguments

Some test arguments located in the test file as specifically formatted comments.
See list of such arguments and example of
usage in [tests](../test/integration_test/in_file_args_test.dart).
