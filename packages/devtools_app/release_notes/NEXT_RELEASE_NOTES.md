This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/development/tools/devtools/release-notes).

# DevTools 2.22.0 release notes

Dart & Flutter DevTools - A Suite of Performance Tools for Dart and Flutter

## General updates
* Prevent crashes if there is no main isolate - [#5232](https://github.com/flutter/devtools/pull/5232)

## Inspector updates
TODO: Remove this section if there are not any general updates.

## Performance updates
TODO: Remove this section if there are not any general updates.

## CPU profiler updates

* Display stack frame uri inline with method name to ensure the URI is always visible
in deeply nested trees - [#5181](https://github.com/flutter/devtools/pull/5181)
* Add the ability to filter by method name or source URI - [#5204](https://github.com/flutter/devtools/pull/5204)
* Add ability to inspect statistics for a CPU profile - [#5317](https://github.com/flutter/devtools/pull/5317)

## Memory updates
* Change filter default to show only project and 3rd party dependencies [#5201](https://github.com/flutter/devtools/pull/5201).
* Support expression evaluation in console for running application [#5248](https://github.com/flutter/devtools/pull/5248).
* Add column `Persisted` for memory diffing [#5290](https://github.com/flutter/devtools/pull/5290).

## Debugger updates
* Add support for browser navigation history when navigating using the `File Explorer` [#4906](https://github.com/flutter/devtools/pull/4906).
* Designate positional fields for `Record` types with the getter syntax beginning at `$1` [#5272](https://github.com/flutter/devtools/pull/5272)

## Network profiler updates
* Improve reliability and performance of the Network tab - [#5056](https://github.com/flutter/devtools/pull/5056)

## Logging updates
TODO: Remove this section if there are not any general updates.

## App size tool updates
TODO: Remove this section if there are not any general updates.

## Changelog
More details about changes and fixes are available in the DevTools
[changelog](https://github.com/flutter/devtools/blob/master/CHANGELOG.md).
