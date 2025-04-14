<!--
Copyright 2025 The Flutter Authors
Use of this source code is governed by a BSD-style license that can be
found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
-->
This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.46.0 release notes

The 2.46.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](/tools/devtools/overview).

## General updates

* Prevent web apps from remaining paused after triggering a hot-restart from
DevTools. - [#9125](https://github.com/flutter/devtools/pull/9125)

* Added a memory pressure warning that allows you to reduce the memory usage of
DevTools in order to avoid an OOM crash. -
[#8989](https://github.com/flutter/devtools/pull/8989),
[#8997](https://github.com/flutter/devtools/pull/8997),
[#8998](https://github.com/flutter/devtools/pull/8998)

* Fixed various memory leaks and lifecycle issues. - 
[#8901](https://github.com/flutter/devtools/pull/8901),
[#8902](https://github.com/flutter/devtools/pull/8902),
[#8907](https://github.com/flutter/devtools/pull/8907),
[#8917](https://github.com/flutter/devtools/pull/8917),
[#8932](https://github.com/flutter/devtools/pull/8932),
[#8933](https://github.com/flutter/devtools/pull/8933),
[#8934](https://github.com/flutter/devtools/pull/8934),
[#8935](https://github.com/flutter/devtools/pull/8935),
[#8937](https://github.com/flutter/devtools/pull/8937),
[#8953](https://github.com/flutter/devtools/pull/8953),
[#8969](https://github.com/flutter/devtools/pull/8969),
[#8970](https://github.com/flutter/devtools/pull/8970),
[#8975](https://github.com/flutter/devtools/pull/8975)

* Fix a bug with the review history on disconnect experience. -
[#8985](https://github.com/flutter/devtools/pull/8985)

* Fixed bug where DevTools would automatically resume instead of
pausing on breakpoint on connection. - 
[#8991](https://github.com/flutter/devtools/pull/8991)

* Prevented text inputs from stealing focus from the IDE. - 
[#9091](https://github.com/flutter/devtools/pull/9091)

## Inspector updates

TODO: Remove this section if there are not any general updates.

## Performance updates

TODO: Remove this section if there are not any general updates.

## CPU profiler updates

TODO: Remove this section if there are not any general updates.

## Memory updates

TODO: Remove this section if there are not any general updates.

## Debugger updates

TODO: Remove this section if there are not any general updates.

## Network profiler updates

TODO: Remove this section if there are not any general updates.

## Logging updates

TODO: Remove this section if there are not any general updates.

## App size tool updates

TODO: Remove this section if there are not any general updates.

## Deep links tool updates

TODO: Remove this section if there are not any general updates.

## VS Code Sidebar updates

TODO: Remove this section if there are not any general updates.

## DevTools Extension updates

TODO: Remove this section if there are not any general updates.

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.46.0).
