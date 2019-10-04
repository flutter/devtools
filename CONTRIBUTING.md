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
- `pub get`

From a separate terminal:
- `cd <path/to/flutter-sdk>/examples/flutter_gallery`
- ensure the iOS Simulator is open (or a physical device is connected)
- `flutter run`

From the packages/devtools_app directory:
- `pub global activate webdev` (install webdev globally)
- `export PATH=$PATH:~/.pub-cache/bin` (make globally activated packages available from the command line)
- `webdev serve`

Then, open a browser window to the local url specified by webdev. After the page has loaded, append
`?port=xxx` to the url, where xxx is the port number of the service protocol port, as specified by
the `flutter run` output.

- `flutter run`
- `open http://localhost:8080`

`webdev` provides a fast development server that incrementally
rebuilds the portion of the application that was edited each time you reload
the page in the browser. If initial app load times become slow as this tool
grows, we can integrate with the hot restart support in `webdev`.

### Developing with VS Code

#### DevTools

If you're using VS Code to work on DevTools you can run DevTools from the editor
using the VS Code tasks without having to run `webdev serve` in a terminal window:

- Open the root of the repository in VS Code
- Press `F5`

This will serve the application in the background and launch Google Chrome. Subsequent
launches will just re-launch the browser since the task remains running in the background
and rebuilding as necessary.

#### DevTools Server

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

### Running tests that depend on the Flutter SDK

Make sure your Flutter SDK matches the tip of trunk before
running these tests.

```
cd packages/devtools_app
pub run test -j1 --tags useFlutterSdk
```

### Run all other tests

```
cd packages/devtools_app
pub run test --exclude-tags useFlutterSdk
pub run build_runner test -- --exclude-tags useFlutterSdk --platform chrome-no-sandbox
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

## third_party dependencies

All content not authored by the Flutter team must go in the third_party
directory. As an expedient to make the third_party code work well with our build scripts,
code in third_party should be given a stub pubspec.yaml file so that you can
reference the resources from the packages directory from
`packages/devtools_app/web/index.html`
