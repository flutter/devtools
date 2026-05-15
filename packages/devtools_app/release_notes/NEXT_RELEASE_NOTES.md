<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
This is a draft for future release notes that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.59.0 release notes

The 2.59.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](/tools/devtools).

## General updates

* Fixed a `RangeError` thrown by `SplitPane` when the parent rebuilt the
  widget with a different number of children, for example when toggling a
  panel in or out of the layout. -
  [#9822](https://github.com/flutter/devtools/pull/9822)

## Inspector updates

- Fixed an issue where hover tooltips in the widget tree were being clipped by the window boundaries. [#9823](https://github.com/flutter/devtools/pull/9823)

## Performance updates

TODO: Remove this section if there are not any updates.

## CPU profiler updates

TODO: Remove this section if there are not any updates.

## Memory updates

* Added the ability to pin classes to the top of the Profile Memory table. [#8898](https://github.com/flutter/devtools/issues/8898)

## Debugger updates

TODO: Remove this section if there are not any updates.

## Network profiler updates

TODO: Remove this section if there are not any updates.

## Logging updates

TODO: Remove this section if there are not any updates.

## App size tool updates

TODO: Remove this section if there are not any updates.

## Deep links tool updates

TODO: Remove this section if there are not any updates.

## VS Code sidebar updates

TODO: Remove this section if there are not any updates.

## DevTools extension updates

TODO: Remove this section if there are not any updates.

## Advanced developer mode updates

TODO: Remove this section if there are not any updates.

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.59.0).
