<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
This is a draft for future release notes that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.63.0 release notes

The 2.63.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](/tools/devtools).

## General updates

* Reused source maps across error reports instead of fetching and parsing them
  repeatedly. [#9910](https://github.com/flutter/devtools/issues/9910)

* Added guidance to run "flutter attach" when a Flutter debug app cannot
  evaluate expressions and a debug-only screen is unavailable.
  [#4091](https://github.com/flutter/devtools/issues/4091)

TODO: Remove this section if there are not any updates.

* Improved the readability of ANSI-colored text in the console and logging
screens: colors that are hard to see against the current light or dark theme,
such as black or white, are now adjusted to remain legible.
[#10060](https://github.com/flutter/devtools/pull/10060)
* Validated incoming DevTools server requests by requiring `POST` (with
  `X-DevTools-Request`) or `OPTIONS` methods and validating `Host`, `Origin`,
  and `Sec-Fetch-Site` headers to protect against cross-site request forgery
  (CSRF), DNS rebinding, and cross-origin attacks.
  [#10082](https://github.com/flutter/devtools/pull/10082)

## Inspector updates

TODO: Remove this section if there are not any updates.

## Performance updates

* Fixed the Frame Analysis tab showing "No timeline event analysis data
  available for this frame" when a frame is selected before its timeline events
  have been fetched from the VM.
  [#10050](https://github.com/flutter/devtools/pull/10050)
* Fixed a bug where data exported from the Performance screen could be
  missing the most recent timeline events. -
  [#10055](https://github.com/flutter/devtools/pull/10055),
  [#9731](https://github.com/flutter/devtools/issues/9731)

## CPU profiler updates

TODO: Remove this section if there are not any updates.

## Memory updates

TODO: Remove this section if there are not any updates.

## Debugger updates

TODO: Remove this section if there are not any updates.

## Network profiler updates

TODO: Remove this section if there are not any updates.

## Logging updates

* Corrected time units and cumulative nature of GC events.
  [#9890](https://github.com/flutter/devtools/pull/9890)
* Fixed a bug where long `dart:developer` log messages lost their structured
  Details view. -
  [#10011](https://github.com/flutter/devtools/pull/10011),
* Fixed ANSI-colored log messages rendering with black text and a larger font,
  and removed raw ANSI escape codes from the Details view. -
  [#10028](https://github.com/flutter/devtools/pull/10028)
TODO: Remove this section if there are not any updates.

## App size tool updates

* Fixed treemap tooltip text color across light and dark theme
  [#10035](https://github.com/flutter/devtools/pull/10035)

## Deep links tool updates

TODO: Remove this section if there are not any updates.

## VS Code sidebar updates

TODO: Remove this section if there are not any updates.

## DevTools extension updates

* Validated DevTools extension filesystem access by rejecting non-local
  `file://` URIs (such as UNC paths), invalid `buildLocation` paths, and broken
  or out-of-bounds symbolic links to prevent extensions from accessing arbitrary
  files outside the package root or build directory.
  [#10083](https://github.com/flutter/devtools/pull/10083)

## Advanced developer mode updates

TODO: Remove this section if there are not any updates.

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.63.0).
