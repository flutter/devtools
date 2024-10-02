This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.40.0 release notes

The 2.40.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](/tools/devtools/overview).

## General updates

* Add a setting that allows users to opt-in to loading DevTools
with WebAssembly. - [#8270](https://github.com/flutter/devtools/pull/8270)

    ![Wasm opt-in setting](images/wasm_setting.png "DevTools setting to opt into wasm.")

* Removed the legacy Provider screen from DevTools. The `package:provider` tool is now
distributed as a DevTools extension from `package:provider`. Upgrade your `package:provider`
dependency to use the extension. - [#8364](https://github.com/flutter/devtools/pull/8364)

* Fixed a bug that was causing the DevTools release notes to always
show. - [#8277](https://github.com/flutter/devtools/pull/8277)

* Added support for loading extensions in pub workspaces
  [8347](https://github.com/flutter/devtools/pull/8347).

* Mapped error stacktraces to use the Dart source code locations so that they are human-
  readable. - [#8385](https://github.com/flutter/devtools/pull/8385)

* Added handling for IDE theme change events to update embedded DevTools UI. -
[#8336](https://github.com/flutter/devtools/pull/8336)

## Inspector updates

- Added a setting to the Flutter Inspector controls that allows users to opt-in to the newly redesigned Flutter Inspector. - [#8342](https://github.com/flutter/devtools/pull/8342)

  ![New inspector opt-in setting](images/new_inspector.png "DevTools setting to opt into the new Flutter Inspector.")

## Performance updates

* Fixed an issue with the "Refreshing timeline" overlay that was getting shown
when it should not have been. - [#8318](https://github.com/flutter/devtools/pull/8318)

## CPU profiler updates

TODO: Remove this section if there are not any general updates.

## Memory updates

TODO: Remove this section if there are not any general updates.

## Debugger updates

TODO: Remove this section if there are not any general updates.

## Network profiler updates

* Resolved an issue in .har export where response content was sometimes missing in the data. - [#8333](https://github.com/flutter/devtools/pull/8333)

## Logging updates

TODO: Remove this section if there are not any general updates.

## App size tool updates

TODO: Remove this section if there are not any general updates.

## Deep links tool updates

- Added support for validating iOS deep link settings. - [#8394](https://github.com/flutter/devtools/pull/8394)

  ![Deep link validator for iOS](images/deep_link_ios.png "DevTools Deep link validator Page")

## VS Code Sidebar updates

TODO: Remove this section if there are not any general updates.

## DevTools Extension updates

TODO: Remove this section if there are not any general updates.

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.40.0).
