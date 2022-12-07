## Instructions for running a DevTools integration test

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

4. Run your DevTools integration test:

```shell
flutter drive \
  --driver=integration_test/test_driver/integration_test.dart \
  --target=integration_test/path/to/test.dart \
  -d chrome
```