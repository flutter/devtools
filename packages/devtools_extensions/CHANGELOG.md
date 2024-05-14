## 0.2.0-dev.0
* Deprecate the `DevToolsExtension.requiresRunningApplication` field.
* Update `extension_config_spec.md` to include an optional field `requiresConnection`.
* Bump `devtools_shared` dependency to `^10.0.0`.
* Fix file locations in the `dart_foo` extension example.
* Bump `vm_service` dependency to `^14.2.1`.
* Dispose `DTDManager` when the `DevToolsExtension` widget state is disposed.
* Add an example of a standalone extension.
* Add examples of Dart and Flutter tests that can be ran and connected to
available DevTools extensions.
* Add an example of interacting with the Dart Tooling Daemon from a DevTools extension.

## 0.1.1
* Update the simulated environment help dialogs with information about the
new `--print-dtd` CLI flag.
* Bump the minimum Dart and Flutter SDK versions to `3.4.0-282.1.beta` and
`3.22.0-0.1.pre` respectively.
* Bump `devtools_app_shared` to ^0.1.1-dev.0
* Bump `devtools_shared` to ^8.1.1-dev.0

## 0.1.0
* Bump `devtools_app_shared` to ^0.1.0
* Update readme to use `pub add` instead of explicit package version.
* Bump `devtools_shared` to ^8.1.0

## 0.0.14
* Add a global `dtdManager` for interacting with the Dart Tooling Daemon.
* Add support for connecting to the Dart Tooling Daemon from the
simulated DevTools environment.
* Add help buttons to the VM Service and DTD connection text fields in the
simulated DevTools environment.
* Bump `package:vm_service` dependency to ^14.0.0.
* Refactor `example` directory to support more package examples.
* Add an example of providing an extension from a pure Dart package.
* Update the `example/README.md`.
* Add a `devtools_extensions validate` for validating extension requirements.
* Update the `README.md` to make it clear that you can build a DevTools
extension as a standalone tool.

## 0.0.13
* Bump `package:web` to `^0.4.1`.
* Fix `README.md` instructions for adding a `.pubignore` file.
* Make Simulated DevTools Environment Panel collapsible.

## 0.0.12
* Fix a bug preventing Dart server apps from connecting to DevTools extensions.

## 0.0.11
* Add error messaging when `extensionManager` or `serviceManager` are accessed before they
are initialized.
* Improve dartdoc for `DevToolsExtension`, `extensionManager`, and `serviceManager`.
* Migrate from `dart:html` to `package:web`.
* Add `utils.dart` library with helper for message event parsing.

## 0.0.10
* Bump minimum Dart SDK version to `3.3.0-91.0.dev` and minimum Flutter SDK version to `3.17.0-0.0.pre`.
* Add a test target to the `app_that_uses_foo` example that can also be debugged
with the DevTools extension provided by `package:foo`.
* Add an example of performing expression evaluations from a DevTools extension.
* Add an example of registering a service extension and calling it from a DevTools extension.
* Document the DevTools extension examples.
* Add documentation to [ExtensionManager] public APIs.
* Fix some bugs with the `build_and_copy` command for Windows.
* Add an example `launch.json` file in the `example/foo` directory.
* Clean up the package readme to make instructions Windows-compatible.
* Update the README with instructions for joining the Flutter Discord server.
* Bump `package:devtools_shared` dependency to ^6.0.1
* Bump `package:devtools_app_shared` dependency to ^0.0.7
* Bump `package:vm_service` dependency to ^13.0.0.

## 0.0.9
* Add a link to the new #devtools-extension-authors Discord channel in the README.md.
* Fix typos that incorrectly used snake case instead of camel case for `config.yaml` examples.
* Add a VS Code launch config for the `app_that_uses_foo` example app.

## 0.0.8
* Fix the `build_and_copy` command so that it succeeds when there is not
an existing `extension/devtools/build` directory.

## 0.0.7
* Update the `build_and_copy` command to stop copying unnecessary files.
* Add `ExtensionManager.unregisterEventHandler` method.
* Update README.md to include `.pubignore` recommendation.
* Add integration testing.

## 0.0.6
* Bump `package:devtools_app_shared` dependency to version ^0.0.4.

## 0.0.5
* Ensure theme and vm service connection are preserved on refresh of the extension
iFrame or the simulated DevTools environment.
* Add a `forceReload` endpoint to the extensions API.
* Add a `toString()` representation for `DevToolsExtensionEvent`.
* Add `ignoreIfAlreadyDismissed` parameter to `ExtensionManager.showBannerMessage` api.
* Update README.md to include package publishing instructions.

## 0.0.4
* Bump `package:vm_service` dependency to ^11.10.0.
* Fix a leaking event listener in the simulated DevTools environment.

## 0.0.3
* Connect the template extension manager to the VM service URI that is passed as a
query parameter to the embedded extension iFrame.
* Add built-in theme support for DevTools extensions (light theme and dark theme).
* Add event direction to the `DevToolsExtensionEventType` api.
* Add an end to end example of a DevTools extension in the `example/` directory.
* Add exception handling to `devtools_extensions build_and_copy` command.
* Add `showNotification` and `showBannerMessage` endpoints to the extensions API.
* Add hot reload and hot restart actions to the simulated DevTools environment.
* Update `build_and_copy` command, as well as documentation, to reference `config.yaml`
instead of `config.json`, as required by `package:extension_discovery` v2.0.0.

## 0.0.2
* Add a simulated DevTools environment that for easier development.
* Add a `build_and_copy` command to build a devtools extension and copy the output to the
parent package's extension/devtools directory.

## 0.0.2-dev.0

* Add missing dependency on `package:devtools_shared`.

## 0.0.1-dev.0

* Initial commit. This package is under construction.
