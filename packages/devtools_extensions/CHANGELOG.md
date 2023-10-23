## 0.0.10
* Bump the `devtools_shared` dependency to ^5.0.0

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
