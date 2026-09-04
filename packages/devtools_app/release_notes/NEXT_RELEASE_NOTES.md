<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
This is a draft for future release notes that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.61.0 release notes

The 2.61.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](/tools/devtools).

## General updates

* Fixed unreadable text in the release notes panel, where blockquotes were
  drawn on a hard coded light blue background in the dark theme.
  [#9957](https://github.com/flutter/devtools/pull/9957)

## Inspector updates

* Added the widget source file path to the Inspector details pane
  (`filename.dart:line:column`), matching legacy Inspector behavior. -
  [#9972](https://github.com/flutter/devtools/pull/9972),
  [#9922](https://github.com/flutter/devtools/issues/9922)

## Performance updates

TODO: Remove this section if there are not any updates.

## CPU profiler updates

* Fixed a bug where resizing the CPU flame chart changes the timing values
  across the top of the chart.
  [#9915](https://github.com/flutter/devtools/pull/9915)

## Memory updates

* Added the ability to pin classes to the top of the Profile Memory table. [#8898](https://github.com/flutter/devtools/issues/8898)

## Debugger updates

* Prevent values from being garbage-collected, while being evaluated.
  [#9885](https://github.com/flutter/devtools/pull/9885)
* Update to latest version of the Dart syntax highlighting grammar
  [#9920](https://github.com/flutter/devtools/pull/9920).
* Fix a bug in the TextMate grammar parser that could result in code after
  comments being classified as comments.
  [#9921](https://github.com/flutter/devtools/pull/9921).
* Fixed an overflow in the debugging controls when the Debugger screen is
  narrow, such as when DevTools is embedded in an IDE side panel. The controls
  now scroll horizontally instead of overflowing.
  [#9949](https://github.com/flutter/devtools/pull/9949)

## Network profiler updates

* Added WebSocket support to the Network profiler, including WebSocket
  connection details, lifecycle events, frame-level inspection, and connection
  timing information. [#9968](https://github.com/flutter/devtools/pull/9968)
* Fixed an issue where the Network tab would stop capturing HTTP requests after
  a hot restart. -
  [#9856](https://github.com/flutter/devtools/pull/9856)
* Fixed an issue where the Network tab would stop capturing new HTTP requests
  after pressing Clear while recording. -
  [#9856](https://github.com/flutter/devtools/pull/9856)

## Logging updates

* Correct time units and cumulative nature of GC events.
  [#9890](https://github.com/flutter/devtools/pull/9890)

## App size tool updates

TODO: Remove this section if there are not any updates.

## Deep links tool updates

* Added a "Watch tutorial" link to the status line that points to the
  [deep links video tutorial](https://youtu.be/d7sZL6h1Elw).
  [#9925](https://github.com/flutter/devtools/pull/9925)

## VS Code sidebar updates

TODO: Remove this section if there are not any updates.

## DevTools extension updates

* Hide the DevTools extensions menu button in single-screen embedded mode (`EmbedMode.embedOne`) on standard screens.
  [#8507](https://github.com/flutter/devtools/issues/8507)

## Advanced developer mode updates

TODO: Remove this section if there are not any updates.

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.61.0).
