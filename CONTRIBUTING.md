# Contributing code

![GitHub contributors](https://img.shields.io/github/contributors/flutter/devtools.svg)

We gladly accept contributions via GitHub pull requests!
This page instructs how to contribute code changes to DevTools.

> If you just want to test newest functionality, follow
[beta testing guidance](https://github.com/flutter/devtools/blob/master/BETA_TESTING.md).

Before contributing code:

1. Complete the
[Contributor License Agreement](https://cla.developers.google.com/clas).
You can do this online, and it only takes a minute.

2. Understand [coding agreements](packages/README.md).

## Workflow for making changes

- Change flutter to the latest flutter candidate:
    `./tool/update_flutter_sdk.sh --local`
- Create a branch from your cloned repo: `git checkout -b myBranch`
- Refresh local code: `sh tool/refresh.sh`
- Implement your changes
- Commit work to your branch: `git commit -m “description”`
- Push to your branch: `git push origin myBranch`
- Navigate to the Pull Requests tab in the main [DevTools repo](https://github.com/flutter/devtools). You should see a popup to create a pull request from the branch in your cloned repo to DevTools master. Create a pull request.

### Keeping your fork in-sync

- Pull the code from the upstream DevTools and refresh local code: `sh tool/pull_and_refresh.sh`

### Announcing your changes

If your improvement is user-facing, document it in
[NEXT_RELEASE_NOTES.md](packages/devtools_app/release_notes/NEXT_RELEASE_NOTES.md).

## Development prep

### Configure DevTools

1. If you haven't already, follow the [instructions](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh) to generate a new SSH key and connect to Github with SSH
2. Follow the [instructions](https://docs.github.com/en/get-started/quickstart/fork-a-repo) to fork the DevTools repo to your own Github account, and clone using SSH
3. Make sure to [configure Git to keep your fork in sync](https://docs.github.com/en/get-started/quickstart/fork-a-repo#configuring-git-to-sync-your-fork-with-the-original-repository) with the main DevTools repo
4. Finally, run `sh tool/refresh.sh` to pull the latest version from repo, generate missing code and upgrade dependencies.

### Connect to application

From a separate terminal, start running a flutter app to connect to DevTools:
- `git clone https://github.com/flutter/gallery.git` (this is an existing application with many examples of Flutter widgets)
- `cd gallery`
- ensure your flutter channel is the one required by the [gallery documentation](https://github.com/flutter/gallery#running-flutter-gallery-on-flutters-master-channel)
- ensure the iOS Simulator is open (or a physical device is connected)
- `flutter run`
- copy the "Observatory debugger and profiler" uri printed in the command output, to connect to the app from DevTools later

### **[Optional]** Enable and activate DCM (Dart Code Metrics)

**Note:** Enabling and activating DCM is optional. When you open a PR, the CI bots will show you any DCM warnings introduced by your change which should be fixed before submitting.

**[Contributors who work at Google]** You can use the Google-purchased license key to activate DCM. See [go/dash-devexp-dcm-keys](http://goto.google.com/dash-devexp-dcm-keys).

**[All other contributors]** Please follow instructions at <https://dcm.dev/pricing/>. You can either use the free tier of DCM, or purchase a team license. Note that the free tier doesn't support all the rules of the paid tier, so you will also need to consult the output of the Dart Code Metrics workflow on Github when you open your PR.

To enable DCM:

1. Install the executable for your target platform. You can refer to [this guide](https://dcm.dev/docs/teams/getting-started/#installation).
2. [Get the license key](http://goto.google.com/dash-devexp-dcm-keys) and activate DCM. To do so, run `dcm activate --license-key=YOUR_KEY` from the console.
3. Install the extension for your IDE. If you use VS Code, you can get it from [the marketplace](https://marketplace.visualstudio.com/items?itemName=dcmdev.dcm-vscode-extension). If you use IntelliJ IDEA or Android Studio, you can find the plugin [here](https://plugins.jetbrains.com/plugin/20856-dcm).
4. Reload the IDE.

**Note:** DCM issues can be distinguished from the Dart analyzer issues by their name: DCM rule names contain `-`. Some of the issues can be fixed via CLI, to do so, run `dcm fix` for any directory. To apply `dcm fix` on a file save in the IDE, refer to [this guide](https://dcm.dev/docs/teams/ide-integrations/vscode/#extension-capabilities).

## Development

*NOTE:* Though DevTools is shipped as a Flutter Web app, we recommend developing as a Flutter Desktop app where possible for a more efficient development workflow. Please see the [Desktop Embedder] section below for instructions on running DevTools as a Flutter Desktop app.

To pull fresh version, regenerate code and upgrade dependencies:

- `sh tool/pull_and_refresh.sh`

To regenerate mocks and upgrade dependencies (after switching branches, for example):

- `sh tool/refresh.sh`

To run DevTools as a Flutter web app, with all experiments enabled, from the packages/devtools_app directory:

- `flutter run -d chrome  --dart-define=enable_experiments=true`

To test release performance:

- `flutter run -d web-server --release --dart-define=FLUTTER_WEB_USE_SKIA=true`

You can also use `-d headless-server`, which will start a headless server that serves the HTML
files for the DevTools Flutter app.

To connect to your running application, paste the earlier copied observatory URL into the section "Connect to a Running App" in DevTools.

To enable all experiments by default when you are running with VS Code, add the following to your debugging configuration:

```
"args": [
  "--dart-define=enable_experiments=true"
]
```

## Development (DevTools server + DevTools Flutter web app)

To develop with a workflow that exercises the DevTools server <==> DevTools client connection,
from the main devtools/ directory run:

```
export LOCAL_DART_SDK=/path/to/dart-sdk
dart ./tool/build_e2e.dart
```
* Note: the LOCAL_DART_SDK needs to point to a local checkout of [dart-sdk](https://github.com/dart-lang/sdk/tree/main)
* Note: if you are also developing server side code, e.g. the devtools_shared package, add a devtools_shared path override to `<path-to-dart-sdk>/pkg/dds/pubspec.yaml`.

That will:
- start the devtools server
- start an instance of `flutter run -d web-server` from the `packages/devtools_app` directory
- proxy all web traffic the devtools server doesn't handle directly to the `flutter run`
  development web server

You can then open a browser at the regular DevTools server URL (typically http://127.0.0.1:9100).
When you make changes on disk, you can hit `r` in your command-line to rebuild the app, and
refresh in your browser to see the changes. Hit `q` in the command line to terminate both the
`flutter run` instance and the devtools server instance.

## Development (VS Code Integration)

To test integration with VS Code, you can instruct the Dart extension to run DevTools and the server from local code. You will need to have the Dart SDK source set up (see [dart-lang/sdk/CONTRIBUTING.md](https://github.com/dart-lang/sdk/blob/main/CONTRIBUTING.md#getting-the-code)) and you will need version v3.47 or newer of the Dart extension for VS Code.

Open your VS Code settings (Run the **Preferences: Open User Settings (JSON)** command from the command palette (`F1`)) and add the following to your settings:

```js
"dart.customDevTools": {
	"script": "/path/to/devtools/tool/build_e2e.dart",
	"cwd": "/path/to/devtools",
	"env": {
		"LOCAL_DART_SDK": "/path/to/dart-sdk/sdk"
	}
},
```

This instructs VS Code to run the `tool/build_e2e.dart` script instead of running `dart devtools`. You must set the `cwd` and `LOCAL_DART_SDK` env variable correctly for the script to work.

Next, restart VS Code (or run the **Developer: Reload Window** command from the command palette (`F1`)) and DevTools will be run from your local code. After making any code changes to DevTools or the server, you will need to re-run the **Developer: Reload Window** command to rebuild and restart the server.

### Running with Flutter Desktop

You can also run DevTools using the Flutter desktop embedder on linux or macos. Some DevTools features only work on the web, like the embedded Perfetto trace viewer or DevTools analytics, but the limitations on the desktop app are few.

The advantage of developing with the desktop embedder is that you can use hot reload to speed up your development cycle.

To run DevTools with the desktop embedder, you can run with either of the following from `devtools/packages/devtools_app`:

- `flutter run -d macos`
- `flutter run -d linux`

If this  fails, you may need to run `flutter create .` from `devtools/packages/devtools_app` to generate the updated files for your platform.

## Developing with VS Code

### DevTools Web

If you're using VS Code to work on DevTools you can run DevTools from the editor
using the VS Code tasks without having to run in a terminal window:

- Open the root of the repository in VS Code
- Press `F5`

This will serve the application in the background and launch Google Chrome. Subsequent
launches will just re-launch the browser since the task remains running in the background
and rebuilding as necessary.

## Automated Testing

### Running tests

Before running tests, make sure your Flutter SDK matches the version that will be used on
the bots. To update your local flutter version, run:

```
./tool/update_flutter_sdk.sh --local

```

Auto-generated mocks are required for running the tests. If you haven't run refresh
script yet, run:
```
./tool/refresh.sh
```

Now you can proceed with running DevTools tests:

```
cd packages/devtools_app
flutter test -j1
```

The flag `-j1` tells Flutter to run tests with 1 concurrent test runner. If your test run does
not include the directory `devtools_app/test/integration_tests`, then you do not need to include
this flag.

### Updating golden files

**Note: golden images should only be generated on MacOS.**

Golden image tests will fail for one of three reasons:

1) The UI has been _intentionally_ modified.
2) Something changed in the Flutter framework that would cause downstream changes for our tests.
3) The UI has been _unintentionally_ modified, in which case we should not accept the changes.

For valid golden image updates (1 and 2 above), the failing golden tests will need to be ran
with the `--update-goldens` flag.

Before updating the goldens, ensure your version of Flutter matches the version of Flutter that
will be used on the bots. To update your local flutter version, run:

```
./tool/update_flutter_sdk.sh --local
```

Now you can proceed with updating the goldens:

```
flutter test <path/to/my/test> --update-goldens
```

To update goldens for all tests, run:
```
flutter test test/ --update-goldens
```

## Manual Testing

To explore DevTools with all experimental features enabled:

1. [Configure](https://docs.flutter.dev/get-started/install) Dart or Flutter.

2. Start DevTools:
```
git clone git@github.com:flutter/devtools.git
./devtools/tool/update_flutter_sdk.sh
cd devtools/packages/devtools_app
../../tool/flutter-sdk/bin/flutter run -d chrome --dart-define=enable_experiments=true
```

3. Paste URL of your application (for example [Gallery](#connect-to-application)) to the connection textbox.

## third_party dependencies

All content not authored by the Flutter team must go in the third_party
directory. As an expedient to make the third_party code work well with our build scripts,
code in third_party should be given a stub pubspec.yaml file so that you can
reference the resources from the packages directory from
`packages/devtools_app/web/index.html`

