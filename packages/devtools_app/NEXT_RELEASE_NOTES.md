This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/development/tools/devtools/release-notes).

# DevTools 2.21.0 release notes

Dart & Flutter DevTools - A Suite of Performance Tools for Dart and Flutter

## General updates

* Fix several issues in syntax highlighting that would color variable names that contain reserved words incorrectly and leave `extends`/`implements` clauses uncolored for some classes - [#4948](https://github.com/flutter/devtools/pull/4948)
* Fix an issue in Safari (browsers that do not support RegExp negative lookbehind) that prevented DevTools from loading - [#4938](https://github.com/flutter/devtools/pull/4938)
* Fix an issue that would prevent DevTools connecting to the backend server that would disable some functionality - [#5016](https://github.com/flutter/devtools/pull/5016)
* Added a link to the DevTools [CONTRIBUTING](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md) guide to the About menu, and fixed the Discord link - [#4926](https://github.com/flutter/devtools/pull/4926)
* Fix conflicting colors in light theme - [5067](https://github.com/flutter/devtools/pull/5067)

## Inspector updates
TODO: Remove this section if there are not any general updates.

## Performance updates
* Fix several issues with loading a Performance snapshot into DevTools - [#5048](https://github.com/flutter/devtools/pull/5048), [#4929](https://github.com/flutter/devtools/pull/4929)
* UI polish and cleanup - [#4889](https://github.com/flutter/devtools/pull/4889)

## CPU profiler updates
TODO: Remove this section if there are not any general updates.

## Memory updates

* Improve usability of snapshot diffing [#5015](https://github.com/flutter/devtools/pull/5015)
* UI polish and cleanup - [#4855](https://github.com/flutter/devtools/pull/4855)
* Color code classes [#5030](https://github.com/flutter/devtools/pull/5030)

## Debugger updates

* Added support for viewing profiler hits in the debugger script viewer - [#4831](https://github.com/flutter/devtools/pull/4831)

## Network profiler updates
TODO: Remove this section if there are not any general updates.

## Logging updates
TODO: Remove this section if there are not any general updates.

## App size tool updates
TODO: Remove this section if there are not any general updates.

## Changelog
More details about changes and fixes are available in the DevTools
[changelog](https://github.com/flutter/devtools/blob/master/CHANGELOG.md).
