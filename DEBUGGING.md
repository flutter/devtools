<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->

# Running and debugging DevTools

There are a few different environments that you may need to run DevTools in.
After running DevTools in one of the environments below, connect to a test
application to debug DevTools runtime tooling (the majority of DevTools tools).
See the [Connect DevTools to a test
application](#connect-devtools-to-a-test-application) section below.

## Frontend only (most common)

Most of the time, you will not need to run DevTools with the DevTools server to
test your changes. You can run DevTools in debug mode as either a Flutter web
or Flutter desktop app.

> Note: though DevTools is shipped as a Flutter Web app, we recommend
> developing as a Flutter Desktop app whenever possible for a more efficient
> development workflow. Please see the [running on Flutter
> desktop](#running-devtools-on-flutter-desktop) section below for
> instructions.

- To run DevTools as a Flutter web app **from VS Code**, run with the
  **devtools** configuration and the "Chrome" device.
  - To run with experiments enabled, run from VS Code with the
    **devtools + experiments** configuration.
- To run DevTools as a Flutter web app **from the command line**, run
  `flutter run -d chrome`.
  - To run with experiments enabled, add the flag
    `--dart-define=enable_experiments=true`.

## Frontend + DevTools server

To develop with a workflow that exercises the DevTools server <==> DevTools
client connection, you will need to perform the following set up steps (first
time only).

1. Clone the [Dart SDK](https://github.com/dart-lang/sdk) fron GitHub.
2. The `LOCAL_DART_SDK` environment variable needs to point to this path:
   `export LOCAL_DART_SDK=/path/to/dart/sdk`

If you are also developing server side code (e.g. the `devtools_shared`
package), you will need to modify the `devtools_shared` dependency override in
`sdk/pubspec.yaml` to point to your local `devtools_shared` package:

```yaml
dependency_overrides:
  devtools_shared:
    path: /path/to/devtools/packages/devtools_shared
```

Then you can run DevTools with the server by running the following from
anywhere under the `devtools/` directory:

1. To run the DevTools web app in release mode, served with the DevTools server
   (this emulates the production environment):

   ```
   dt serve
   ```

2. To run the DevTools web app in debug mode, with full debugging support, and
   with a connection to a live DevTools server:

   ```sh
   dt run
   ```

Option 2 is useful for a quicker development cycle. The DevTools build time
will be faster, and you will be able to connect the DevTools web app to an IDE
or another DevTools instance for debugging purposes.

To see the full list of arguments available for either command, please pass the
`-h` flag.

## IDE-embedded DevTools experience

### DevTools + VS Code integration

To test the integration with VS Code, you can set up the Dart VS Code extension
to run DevTools and the server from your local source code. Follow the
[Frontend + DevTools server](#frontend--devtools-server) setup instructions
above.

Open your VS Code settings (Run the
**Preferences: Open User Settings (JSON)** command from the command palette
(`F1`)) and add the following to your settings:

```js
"dart.customDevTools": {
    "path": "/absolute/path/to/devtools/repo",
    "env": {
        "LOCAL_DART_SDK": "/absolute/path/to/sdk",
        // Path to the Flutter SDK that will be used to build DevTools. This may
        // be the path to the included Flutter SDK under the tool/ directory or
        // the path to your local Flutter SDK git checkout.
        "FLUTTER_ROOT": "/absolute/path/to/devtools/tool/flutter-sdk"
    },
    "args": [
        // Arguments that will be passed along to the `dt serve` command.
    ],
},
```

This instructs VS Code to run the `dt serve` command instead of running `dart
devtools`. You must set the `LOCAL_DART_SDK` and `FLUTTER_ROOT` env variables
correctly for the script to work.

Next, restart VS Code (or run the **Developer: Reload Window** command from the
command palette (`F1`)) and DevTools will be run from your local source code.

> Note: After making any code changes to DevTools or the server, you will need
> to re-run the **Developer: Reload Window** command to rebuild and restart the
> server.

### Print-debugging

In order to use and see `print()` calls, open VS Code's own Developer Tools via
the **Developer: Toggle Developer Tools** command from the command palette
(`F1`). `print()` calls are outputted to this Developer Tools panel, in the
**Console** screen.

### DevTools + IntelliJ integration

Follow instructions in the Flutter-IntelliJ repo's `CONTRIBUTING` guide:
[#developing-with-local-devtools](https://github.com/flutter/flutter-intellij/blob/master/CONTRIBUTING.md#developing-with-local-devtools)

## Connect DevTools to a test application

For working on most DevTools tools, a connection to a running Dart or Flutter
app is required. Run any Dart or Flutter app of your choice to connect it to
DevTools. Consider running
[veggieseasons](https://github.com/flutter/samples/tree/main/veggieseasons) or
another Flutter sample since those apps have plenty of interesting code to
debug.

1. Run your Dart or Flutter app.
    > Note: some DevTools features may be unavailable depending on the test app
    > platform (Flutter native, Flutter web, Dart CLI, etc.) or run mode (debug,
    > profile) you choose.
2. Copy the URI printed to the command line (you will use this URI to connect to
   DevTools).

   ```
   "A Dart VM Service on iPhone 14 Pro Max is available at: <copy-this-uri>"
   ```
3. Paste this URI into the connect dialog in DevTools and click "Connect".

   ![Connect dialog example](_markdown_images/connect_dialog_example.png)

## Running DevTools on Flutter Desktop

For a faster development cycle with hot reload, you can run DevTools on Flutter
desktop. Some DevTools features only work on the web, like the embedded
Perfetto trace viewer, DevTools extensions, or WASM support, but the
limitations on the desktop app are few.

To run DevTools with the desktop embedder on MacOS, you can run `flutter run -d
macos` from `devtools/packages/devtools_app`, or you can run DevTools from your
IDE with the `macOS` device selected.

If this fails, you may need to run `flutter create .` from
`devtools/packages/devtools_app` to generate the updated files for your
platform. If you want to run DevTools on Flutter desktop for Windows or Linux,
you will need to generate the files for this platform using the
`flutter create .` command, and then run using
`flutter run -d <windows or linux>`.
