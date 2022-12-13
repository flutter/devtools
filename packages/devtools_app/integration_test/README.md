## Instructions for running a DevTools integration test

### Set up ChromeDriver (one time only)

1. Follow the instructions [here](https://docs.flutter.dev/cookbook/testing/integration/introduction#5b-web) to download ChromeDriver.

2. Add `chromedriver` to your PATH by modifying your `.bash_profile` or `.zshrc`:

```
export PATH=${PATH}:/Users/me/folder_containing_chromedriver/
```

3. Start `chromedriver`:

```
chromedriver --port=4444
```

If you get the error "'chromedriver' cannot be opened because it is from an unidentified developer.", run the following command with your path to the `chromedriver` executable:

```
xattr -d com.apple.quarantine ~/path/to/chromedriver
```

### Running a test

1. Run the integration test script: `dart run integration_test/e2e.dart`

To speed up local development, you can pass in a vm service uri from a Dart or Flutter app running on
your local machine. This saves the cost of spinning up a new test app for each test run. To do this,
pass the vm service uri using the `--test-app-uri=some-uri` run flag.

