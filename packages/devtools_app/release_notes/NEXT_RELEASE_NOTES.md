<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
This is a draft for future release notes that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.58.0 release notes

The 2.58.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](/tools/devtools).

## General updates

TODO: Remove this section if there are not any updates.

## Inspector updates

- Deleted the option to use the legacy inspector.
  [#9782](https://github.com/flutter/devtools/pull/9782)

## Performance updates

- Added a message in the Performance panel when widget rebuild tracking is
  unavailable because the app is running in profile mode. [#9755](https://github.com/flutter/devtools/pull/9755)

## CPU profiler updates

TODO: Remove this section if there are not any updates.

## Memory updates

TODO: Remove this section if there are not any updates.

## Debugger updates

TODO: Remove this section if there are not any updates.

## Network profiler updates

- Added response size column to the Network tab and displayed response size in the request inspector overview.
  [#9744](https://github.com/flutter/devtools/pull/9744)
- Improved HTTP request status classification in the Network tab to better distinguish cancelled, completed, and in-flight requests (for example, avoiding some cases where cancelled requests appeared as pending). [#9683](https://github.com/flutter/devtools/pull/9683)

## Logging updates

- Fixed an issue where log messages containing newline characters were incorrectly split into multiple separate entries in the Logging screen. [#9757](https://github.com/flutter/devtools/pull/9757)

## App size tool updates

TODO: Remove this section if there are not any updates.

## Deep links tool updates

- Pluralized "domain" and "path" in the validation summary notification titles when multiple errors are present. [#9790](https://github.com/flutter/devtools/pull/9790)

## VS Code sidebar updates

TODO: Remove this section if there are not any updates.

## DevTools extension updates

TODO: Remove this section if there are not any updates.

## Advanced developer mode updates

TODO: Remove this section if there are not any updates.

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.58.0).