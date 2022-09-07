## Contributing code

![GitHub contributors](https://img.shields.io/github/contributors/flutter/devtools.svg)

We gladly accept contributions via GitHub pull requests!

You must complete the
[Contributor License Agreement](https://cla.developers.google.com/clas).
You can do this online, and it only takes a minute. If you've never submitted code before,
you must add your (or your organization's) name and contact info to the [AUTHORS](AUTHORS)
file.

## Workflow for making changes

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
[release-notes-next.md](packages/devtools_app/lib/src/framework/release_notes/release-notes-next.md).

## Development prep

1. If you haven't already, follow the [instructions](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh) to generate a new SSH key and connect to Github with SSH
2. Follow the [instructions](https://docs.github.com/en/get-started/quickstart/fork-a-repo) to fork the DevTools repo to your own Github account, and clone using SSH
3. Make sure to [configure Git to keep your fork in sync](https://docs.github.com/en/get-started/quickstart/fork-a-repo#configuring-git-to-sync-your-fork-with-the-original-repository) with the main DevTools repo
4. Finally, run `sh tool/refresh.sh` to pull the latest version from repo, generate missing code and upgrade dependencies.

From a separate terminal, start running a flutter app to connect to DevTools:
- `git clone https://github.com/flutter/gallery.git` (this is an existing application with many examples of Flutter widgets)
- `cd gallery`
- ensure your flutter channel is the one required by the [gallery documentation](https://github.com/flutter/gallery#running-flutter-gallery-on-flutters-master-channel)
- ensure the iOS Simulator is open (or a physical device is connected)
- `flutter run`
- copy the "Observatory debugger and profiler" uri printed in the command output, to connect to the app from DevTools later

## Development

*NOTE:* Though DevTools is shipped as a Flutter Web app, we recommend developing as a Flutter Desktop app where possible for a more efficient development workflow. Please see the [Desktop Embedder] section below for instructions on running DevTools as a Flutter Desktop app.

To pull fresh version, regenerate code and upgrade dependencies:

- `sh tool/pull_and_refresh.sh`

To regenerate mocks and upgrade dependencies (after switching branches, for example):

- `sh tool/refresh.sh`

To run DevTools as a Flutter web app, from the packages/devtools_app directory:

- `flutter run -d chrome`

To test release performance:

- `flutter run -d web-server --release --dart-define=FLUTTER_WEB_USE_SKIA=true`

You can also use `-d headless-server`, which will start a headless server that serves the HTML
files for the DevTools Flutter app.

To connect to your running application, paste the earlier copied observatory URL into the section "Connect to a Running App" in DevTools.

## Development (DevTools server + DevTools Flutter web app)

To develop with a workflow that exercises the DevTools server <==> DevTools client connection,
change to the `packages/devtools` directory, and run:

```
flutter pub get
dart bin/devtools.dart --debug
```

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

### Desktop Embedder

You can also run the app in the Flutter desktop embedder on linux or macos.

*NOTE:* The Linux desktop version only works with the master branch of Flutter (and sometimes this is true for MacOS as well). Syncing
to a the master branch of Flutter may fail with a runner version error. If this occurs run
`flutter create .` from `devtools/packages/devtools_app`, re-generates files in the linux and
macos directories.

Depending on your OS, set up like this:
- `flutter config --enable-macos-desktop`
- `flutter config --enable-linux-desktop`

Now you can run with either of the following:

- `flutter run -d macos`
- `flutter run -d linux`

## Developing with VS Code

### DevTools Web

If you're using VS Code to work on DevTools you can run DevTools from the editor
using the VS Code tasks without having to run in a terminal window:

- Open the root of the repository in VS Code
- Press `F5`

This will serve the application in the background and launch Google Chrome. Subsequent
launches will just re-launch the browser since the task remains running in the background
and rebuilding as necessary.

### DevTools Server

Run and debug the local version of the server with a release build:
- In VS Code on the Debug side bar, switch to the `Run Server with Release Build` config. Press F5.
This will produce a release build of DevTools and then debug the server (`bin/devtools.dart`)
to serve it.
- From CLI, you can run the publish script to create a release build (`./devtools/tool/publish.sh`).
Then `cd packages/devtools` and run `dart bin/devtools.dart`.

If you need to make breaking changes to DevTools that require changes to the server
(such that DevTools cannot run against the live Pub version of devtools_server) it's
critical that the devtools_server is released first and the version numbers in
`packages/devtools/pubspec.yaml` and `packages/devtools_app/pubspec.yaml` are updated.
 Please make sure this is clear on any PRs you open.

## Testing

### Running tests

Make sure your Flutter SDK matches the version specified in `devtools/flutter-version.txt`
before running these tests.

```
cd packages/devtools_app
flutter test -j1 --no-sound-null-safety
```

The flag `-j1` tells Flutter to run tests with 1 concurrent test runner. If your test run does
not include the directory `devtools_app/test/integration_tests`, then you do not need to include
this flag.  For example, it is OK to do the following:

```
flutter test test/ui/ --no-sound-null-safety
```

If you run the tests on other than Linux environment, first time add the flag `--update-goldens`, 
because goldens on your machine will be little different.

### Updating golden files

Some of the golden file tests will fail if Flutter changes the implementation or diagnostic
properties of widgets used by the inspector tests. If this happens, make sure the golden
file output still looks reasonable and execute the following command to update the golden files.

```
./tool/update_goldens.sh
```

This will update the master or stable goldens depending on whether you're on the stable
Flutter branch.

To update goldens for both channels do:

```
flutter channel master
./tool/update_goldens.sh
flutter channel stable
./tool/update_goldens.sh
```

## third_party dependencies

All content not authored by the Flutter team must go in the third_party
directory. As an expedient to make the third_party code work well with our build scripts,
code in third_party should be given a stub pubspec.yaml file so that you can
reference the resources from the packages directory from
`packages/devtools_app/web/index.html`
