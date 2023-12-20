This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.31.0 release notes

The 2.31.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](https://docs.flutter.dev/tools/devtools/overview).

## General updates

* Added a new feature for deep link validation, supporting deep link web checks on Android. - [#6935](https://github.com/flutter/devtools/pull/6935)

## Inspector updates

* When done typing in the search field, the next selection is now automatically selected - [#6677](https://github.com/flutter/devtools/pull/6677)
* Added link to package directory documentation, from the inspect settings dialog - [6825](https://github.com/flutter/devtools/pull/6825)
* Fix bug where widgets owned by the Flutter framework were showing up in the widget tree view -
[6857](https://github.com/flutter/devtools/pull/6857)
* Only cache pub root directories added by the user - [6897](https://github.com/flutter/devtools/pull/6897)
* Remove Flutter pub root if it was accidently cached - [6911](https://github.com/flutter/devtools/pull/6911)

## Performance updates

* Changed raster layer preview background to a checkerboard. - [#6827](https://github.com/flutter/devtools/pull/6827)

## CPU profiler updates

TODO: Remove this section if there are not any general updates.

## Memory updates

TODO: Remove this section if there are not any general updates.

## Debugger updates

* Highlight `extension type` as a declaration keyword,
  highlight the `$` in identifier interpolation as part of the interpolation,
  and properly highlight comments within type arguments. - [6837](https://github.com/flutter/devtools/pull/6837)

## Network profiler updates

TODO: Remove this section if there are not any general updates.

## Logging updates

* Added scrollbar to details pane. - [#6917](https://github.com/flutter/devtools/pull/6917)

## App size tool updates

TODO: Remove this section if there are not any general updates.

## VS Code Sidebar updates

* Fixed an issue that prevented the VS code sidebar from loading in recent beta/master builds. - [#6984](https://github.com/flutter/devtools/pull/6984)

## DevTools Extension updates

* Fixed a couple bugs preventing Dart server apps from connecting to DevTools extensions. - [#6982](https://github.com/flutter/devtools/pull/6982), [#6993](https://github.com/flutter/devtools/pull/6993)

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.31.0).
