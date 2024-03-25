This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.34.0 release notes

The 2.34.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview]({{site.url}}/tools/devtools/overview).

## General updates

* Fixed an issue preventing DevTools from connecting to Flutter apps that are not
launched from Flutter Tools. - [#6848](https://github.com/flutter/devtools/issues/6848)

## Inspector updates

TODO: Remove this section if there are not any general updates.

## Performance updates
* Add a setting to include CPU samples in the Timeline. - [#7333](https://github.com/flutter/devtools/pull/7333), [#7369](https://github.com/flutter/devtools/pull/7369)
* Removed the legacy trace viewer. The legacy trace viwer was replaced with the
embedded Perfetto trace viewer in DevTools version 2.21.1, but was available
behind a setting to ensure a smooth rollout. This release of DevTools removes
the legacy trace viewer entirely. - [#7316](https://github.com/flutter/devtools/pull/7316)

## CPU profiler updates

TODO: Remove this section if there are not any general updates.

## Memory updates

* Enabled export of snapshots and improved snapshotting
performance. - [#7197](https://github.com/flutter/devtools/pull/7197), [#7439](https://github.com/flutter/devtools/pull/7439)

## Debugger updates

TODO: Remove this section if there are not any general updates.

## Network profiler updates

* Improved Network profiler performance. - [#7266](https://github.com/flutter/devtools/pull/7266)
* Fixed a bug where selected pending requests weren't refreshing the tab once updated. - [#7266](https://github.com/flutter/devtools/pull/7266)
* Fixed the JSON viewer so multiline strings are visible in their row, and
  through a tooltip. - [#7389](https://github.com/flutter/devtools/pull/7389)
* Fixed JsonViewer where all of the expanded sections would snap closed. [#7367](https://github.com/flutter/devtools/pull/7367)

## Logging updates

TODO: Remove this section if there are not any general updates.

## Deep Links tool updates

* Automatically populate a list of Flutter projects from the connected
IDE. - [#7415](https://github.com/flutter/devtools/pull/7415)

## App size tool updates

TODO: Remove this section if there are not any general updates.

## VS Code Sidebar updates

TODO: Remove this section if there are not any general updates.

## DevTools Extension updates

TODO: Remove this section if there are not any general updates.

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.34.0).
