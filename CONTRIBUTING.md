## Contributing code

![GitHub contributors](https://img.shields.io/github/contributors/flutter/devtools.svg)

We gladly accept contributions via GitHub pull requests!

You must complete the
[Contributor License Agreement](https://cla.developers.google.com/clas).
You can do this online, and it only takes a minute. If you've never submitted code before,
you must add your (or your organization's) name and contact info to the [AUTHORS](AUTHORS)
file.

## Development

- `git clone https://github.com/flutter/devtools`
- `cd devtools/packages/devtools_app`
- `flutter pub get`

From a separate terminal:
- `cd <path/to/flutter-sdk>/examples/flutter_gallery`
- ensure the iOS Simulator is open (or a physical device is connected)
- `flutter run`

### `dart:html` Web App

To run the `dart:html` build of DevTools currently shipping in production, follow these steps.

From the packages/devtools_app directory:
- `alias build_runner="flutter pub run build_runner"`
- `build_runner serve web`

Then, open a browser window to the local url specified by the tool. After the page has loaded, 
copy and paste the url for the debug service into the DevTools app:

- `Debug service listening on http://localhost:8080/asdfjASD5YJK=`

## Development (Flutter)

To run the experimental Flutter for Web build of DevTools, follow these steps.

First, perform one-time setup:

- `flutter config --enable-web`

Now you can run the app at any time with the flutter command.

From the packages/devtools_app directory:

- `flutter run -d chrome`

To test release performance:

- `flutter run -d web-server --release --dart-define=FLUTTER_WEB_USE_SKIA=true`

You can also use `-d headless-server`, which will start a headless server that serves the HTML
files for the DevTools Flutter app.

### Desktop Embedder

You can also try running the app in the Flutter desktop embedder on linux or macos.

Depending on your OS, set up like this:
- `flutter config --enable-macos-desktop`
- `flutter config --enable-linux-desktop`

Now you can run with either of the following:

- `flutter run -d macos`
- `flutter run -d linux`

### Where to put Flutter code

We also roll DevTools' code into a bazel build system, where we need to run only the non-flutter
code from the app. To facilitate this, please keep code that imports package:flutter under a
directory named 'flutter'.

For example, `lib/src/flutter`, `lib/src/inspector/flutter`, or `test/flutter` are all acceptable
locations to put new Flutter code.

When we are ready to turn down the `dart:html` web version of the app, we will delete all code that
isn't inside of or imported by the flutter code.

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

To work on devtools_server you'll need to temporarily update the devtools pubspec to
reference the local version of devtools_server and make release builds of devtools for
the server to serve:

- In both `packages/devtools/pubspec.yaml` and `packages/devtools_app/pubspec.yaml`, uncomment
 the `path: ../devtools_server` line
  and comment out the version number on the line above.
- Run `pub get` in both packages.

Now you can run and debug the local version of the server with a release build:
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

Make sure your Flutter SDK matches the tip of trunk before
running these tests.

```
cd packages/devtools_app
flutter test -j1
```

The flag `-j1` tells Flutter to run tests with 1 concurrent test runner. If your test run does
not include the directory `devtools_app/test/integration_tests`, then you do not need to include
this flag.  For example, it is OK to do the following:

```
flutter test test/ui/
```

Some tests are intended to run on chrome instead of in the regular Dart VM.  To run these tests,
pass the flag `--platform=chrome` to `flutter test`:

```
flutter test -j1 --platform=chrome
```

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
