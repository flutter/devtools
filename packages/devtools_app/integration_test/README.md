## Instructions for running a DevTools integration test

### Set up ChromeDriver (one time only)

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

### Running a test

- To run all integration tets: `dart run integration_test/all.dart`
- To run a single integration test: `dart run integration_test/single.dart --target=integration_test/test/my_test.dart`

Special flags:

- `--test-app-uri`: to speed up local development, you can pass in a vm service uri from a Dart or Flutter 
app running on your local machine. This saves the cost of spinning up a new test app for each test run. To 
do this, pass the vm service uri using the `--test-app-uri=some-uri` run flag.
- `--enable_experiments`: enables experiments for DevTools within the integration test environment
- `--headless`: this will run the integration test on the 'web-server' device instead of the 'chrome' device, meaning you will not be able to see the integration test run in Chrome when running locally. 
