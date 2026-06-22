<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
This is a draft for future release notes that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.60.0 release notes

The 2.60.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](/tools/devtools).

## General updates

* Fixed a bug where highlighted search matches in tables were unreadable in dark
  mode because the highlight color had become fully opaque. -
  [#9863](https://github.com/flutter/devtools/pull/9863)
* Rejected absolute paths in DevTools server file reads so they stay within
  the `~/.flutter-devtools/` directory and cannot resolve to arbitrary files
  on disk. -
  [#9844](https://github.com/flutter/devtools/pull/9844)

## Inspector updates

- Fixed an issue where the Inspector error badge count would improperly
  increase or disappear during navigation.
  [#9524](https://github.com/flutter/devtools/issues/9524)

## Performance updates

* Fixed a bug where the selected feature tab was not restored when loading
  exported Performance data. -
  [#9861](https://github.com/flutter/devtools/pull/9861)

## CPU profiler updates

TODO: Remove this section if there are not any updates.

## Memory updates

TODO: Remove this section if there are not any updates.

## Debugger updates

TODO: Remove this section if there are not any updates.

## Network profiler updates

* Fixed the Network tab search field becoming disabled after clearing all
  requests, so the search query can now be edited at any time. -
  [#9855](https://github.com/flutter/devtools/pull/9855)

## Logging updates

TODO: Remove this section if there are not any updates.

## App size tool updates

TODO: Remove this section if there are not any updates.

## Deep links tool updates

- Only validate deep links when connected to a Flutter app.
  [#8081](https://github.com/flutter/devtools/issues/8081)

## VS Code sidebar updates

TODO: Remove this section if there are not any updates.

## DevTools extension updates

TODO: Remove this section if there are not any updates.

## Advanced developer mode updates

TODO: Remove this section if there are not any updates.

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.60.0).
