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

TODO: Remove this section if there are not any updates.

## Inspector updates

TODO: Remove this section if there are not any updates.

## Performance updates

TODO: Remove this section if there are not any updates.

## CPU profiler updates

* Fixed a bug where resizing the CPU flame chart changes the timing values
  across the top of the chart.
  [#9915](https://github.com/flutter/devtools/pull/9915)

## Memory updates

TODO: Remove this section if there are not any updates.

## Debugger updates

* Prevent values from being garbage-collected, while being evaluated.
  [#9885](https://github.com/flutter/devtools/pull/9885)
* Update to latest version of the Dart syntax highlighting grammar
  [#9920](https://github.com/flutter/devtools/pull/9920).
* Fix a bug in the TextMate grammar parser that could result in code after
  comments being classified as comments.
  [#9921](https://github.com/flutter/devtools/pull/9921).

## Network profiler updates

* Fixed exported response status in HAR files so that they parse as integers
  instead of strings. [#9900](https://github.com/flutter/devtools/pull/9900)

## Logging updates

* Correct time units and cumulative nature of GC events.
  [#9890](https://github.com/flutter/devtools/pull/9890)

## App size tool updates

TODO: Remove this section if there are not any updates.

## Deep links tool updates

TODO: Remove this section if there are not any updates.

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
