This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/development/tools/devtools/release-notes).

# DevTools 2.24.0 release notes

Dart & Flutter DevTools - A Suite of Performance Tools for Dart and Flutter

## General updates
* Improve the overal performance of DevTools tables - [#5664](https://github.com/flutter/devtools/pull/5664), [#5696](https://github.com/flutter/devtools/pull/5696)

## Inspector updates
TODO: Remove this section if there are not any general updates.

## Performance updates
TODO: Remove this section if there are not any general updates.

## CPU profiler updates
* Fix bug with CPU flame chart selection and tooltips - [#5676](https://github.com/flutter/devtools/pull/5676)

## Memory updates
TODO: Remove this section if there are not any general updates.

## Debugger updates
* Improve support for inspecting `UserTag` and `MirrorReferent` instances - [#5490](https://github.com/flutter/devtools/pull/5490)
* Fixes expression evaluation bug where selecting an autocomplete result for a field would clear the current input - [#5717](https://github.com/flutter/devtools/pull/5717)
* Selecting a stack frame scrolls to the frame location in the source code - [#5722](https://github.com/flutter/devtools/pull/5722)
* Performance improvements when searching in a file, or searching for a file - [#5733](https://github.com/flutter/devtools/pull/5733)
* Disables syntax highlighting for files with more than 100,000 characters due to performance constraints - [#5743](https://github.com/flutter/devtools/pull/5743)
* Fix bug where source code wasn't visible if syntax highlighting for a file was disabled - [#5743](https://github.com/flutter/devtools/pull/5743)


## Network profiler updates
* Added a selector to customize the display type of text and json responses (thanks to @hhacker1999!) - [#5816](https://github.com/flutter/devtools/pull/5816)

## Logging updates
TODO: Remove this section if there are not any general updates.

## App size tool updates
TODO: Remove this section if there are not any general updates.

## Full commit history
More details about changes and fixes are available from the
[DevTools git log.](https://github.com/flutter/devtools/commits/master).
