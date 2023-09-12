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
