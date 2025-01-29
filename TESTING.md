<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
# Testing for DevTools

DevTools is test covered by multiple types of tests, all of which are run on the CI for each DevTools PR / commit:

1. Unit tests
    - tests for business logic
2. Widget tests
    - tests for DevTools UI components using mock or fake data
    - some widget tests may contain golden image testing
3. Partial integration tests
    - tests for DevTools UI and business logic with a real VM service connection to a test app
4. Full integration tests
    - Flutter web integration tests that run DevTools as a Flutter web app and connect it to a real test app
    on multiple platforms (Flutter mobile, Flutter web, and Dart CLI)
5. Benchmark tests
    - Performance benchmark tests that execute DevTools user journeys and verify the rendering performance
    meets expected thresholds.
    - Size benchmark test that verifies the size of the built DevTools web app meets the expected threshold.

## Running DevTools tests

> The following instructions are for unit tests, widget tests, and partial integration tests.
> - For instructions on running and writing **full integration tests**, please see
> [integration_test/README.md](packages/devtools_app/integration_test/README.md). In general, we should first
> try to test cover new features and bug fixes with unit tests or widget tests before writing new integration tests,
> which are slower to run and are not as easy to debug or iterate upon.
> - For instructions on running and writing **benchmark tests**, please see
> [benchmark/README.md](packages/devtools_app/benchmark/README.md).

### Prerequisites
1. Before running tests, make sure your Flutter SDK matches the version that will be used on
the CI. 
    > Note: this step requires that you have followed the [set up instructions](CONTRIBUTING.md#set-up-your-devtools-environment)
    in the DevTools contributing guide regarding cloning the Flutter SDK from GitHub, adding the `dt`
    executable to your PATH, and running `flutter pub get` in the `tool` directory.
    
    To update your local flutter version, run:
    ```shell
    dt update-flutter-sdk --update-on-path
    ```
    > Warning: this will delete any local changes in your Flutter SDK you checked out from git.

2. You may need to re-generate the testing mocks before running the tests:

    ```shell
    dt generate-code --upgrade
    ```

### Run tests

```shell
cd packages/devtools_app
flutter test test/
```

### Updating golden image files

> Note: golden images should only be generated on MacOS.

Golden image tests will fail for one of three reasons:

1. The UI has been _intentionally_ modified.
2. Something changed in the Flutter framework that would cause downstream changes for our tests.
3. The UI has been _unintentionally_ modified, in which case we should **not** accept the changes.

For valid golden image updates (1 and 2 above), the failing golden images will need to be updated. This can
be done in one of two ways:

1. **(Recommended)** If the tests failed on the CI for a PR, we can download the generated golden images directly from GitHub.
    > If you are developing on a non-MacOS machine, this is the only way you'll be able to update the golden images.

    - Navigate to the failed Actions run for your PR on GitHub. Example:

        ![Failed actions run](_markdown_images/failed_actions_run.png)

    - Scroll to the bottom of the Summary view to see the errors from the `macos goldens` job, and the notice containing the golden update command:

        ![Failed goldens notice](_markdown_images/failed_goldens_notice.png)

    - Copy this command and run it locally to apply the golden updates. Please review these updates and ensure
    they are acceptable golden changes. **Important:** this command will only succeed after the golden artifacts
    have been uploaded to Github, which happens once all of the jobs have finished.

2. Update the goldens locally by running the failing test(s) with the `--update-goldens` flag.
    > Due to slight differences in the MacOS environment used by Github actions and your local
    machine, the locally generated goldens may still cause failures on the CI. This is why option
    #1 above is the recommended method for updating goldens images.

    - Before updating the goldens, ensure your version of Flutter matches the version of Flutter that is used
    on the CI (see [prerequsites](#prerequisites) above).

    - Then proceed with updating the goldens:

        ```shell
        flutter test <path/to/my/test> --update-goldens
        ```

        or to update goldens for all tests:

        ```shell
        flutter test test/ --update-goldens
        ```

## Writing DevTools tests

When you add a new feature or fix a bug, please add a corresponding test for your change.

- If there is an existing test file for the feature your code touches, you can add the test case
there.
- Otherwise, create a new test file with the `_test.dart` suffix, and place it in an appropriate
location under the `test/` directory for the DevTools package you are working on.
