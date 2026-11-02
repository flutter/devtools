<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
This is a draft for future release notes that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.62.0 release notes

The 2.62.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](/tools/devtools).

## General updates

* Removed the legacy Provider screen, which was a placeholder to point users to
the `package:provider` DevTools extension. [#10046](https://github.com/flutter/devtools/pull/10046)
* Added user-facing error notifications when importing data files that are
  missing required fields or contain no data for the screen.
  [#10005](https://github.com/flutter/devtools/pull/10005)

## Inspector updates

TODO: Remove this section if there are not any updates.

## Performance updates

* Reduced the memory used when saving Performance data for offline viewing,
  and made the saved files smaller. Files saved with this version cannot be
  opened in older versions of DevTools. Files saved with older versions can
  still be opened.
  [#10034](https://github.com/flutter/devtools/pull/10034),
  [#10010](https://github.com/flutter/devtools/issues/10010)
* Fixed an issue where importing performance data with Flutter frames but no
  timeline trace would treat the data as empty.
  [#10005](https://github.com/flutter/devtools/pull/10005)
* Fixed the Performance page loading forever when the connected app uses a
  timeline recorder that DevTools cannot read from, such as systrace.
  [#10054](https://github.com/flutter/devtools/pull/10054)

## CPU profiler updates

TODO: Remove this section if there are not any updates.

## Memory updates

TODO: Remove this section if there are not any updates.

## Debugger updates

* Improved syntax highlighting of fenced code blocks that use more than three
  backticks.
  [#10021](https://github.com/flutter/devtools/pull/10021)

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
[DevTools git log](https://github.com/flutter/devtools/tree/v2.62.0).
