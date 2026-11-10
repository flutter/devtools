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

TODO: Remove this section if there are not any updates.

* Improved the readability of ANSI-colored text in the console and logging
screens: colors that are hard to see against the current light or dark theme,
such as black or white, are now adjusted to remain legible.
[#10060](https://github.com/flutter/devtools/pull/10060)
* Validated incoming DevTools server requests by requiring `POST` or `OPTIONS`
  methods and loopback `Host`, `Origin`, and `Sec-Fetch-Site` headers to protect
  against cross-site request forgery (CSRF), DNS rebinding, and cross-origin
  attacks.
  [#10082](https://github.com/flutter/devtools/pull/10082)

## Inspector updates

TODO: Remove this section if there are not any updates.

## Performance updates

TODO: Remove this section if there are not any updates.

## CPU profiler updates

TODO: Remove this section if there are not any updates.

## Memory updates

TODO: Remove this section if there are not any updates.

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
[DevTools git log](https://github.com/flutter/devtools/tree/v2.63.0).
