This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.35.0 release notes

The 2.35.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview]({{site.url}}/tools/devtools/overview).

## General updates

TODO: Remove this section if there are not any general updates.

## Inspector updates

* Add a preference for the default inspector view - [#6949](https://github.com/flutter/devtools/pull/6949)

## Performance updates

TODO: Remove this section if there are not any general updates.

## CPU profiler updates

TODO: Remove this section if there are not any general updates.

## Memory updates

* Replaced total size with reachable size in snapshot list. -
[#7493](https://github.com/flutter/devtools/pull/7493)

## Debugger updates

TODO: Remove this section if there are not any general updates.

## Network profiler updates
 
* Added text selection in text viewer for requests and responses. - [#7596](https://github.com/flutter/devtools/pull/7596)
* Added a JSON copy experience to the JSON viewer. - [#7596](https://github.com/flutter/devtools/pull/7596)
  ![An image of the new json copy experience for the JSON viewer](./images/json_viewer_copy.png)

## Logging updates

TODO: Remove this section if there are not any general updates.

## App size tool updates

TODO: Remove this section if there are not any general updates.

## Deep links tool updates

* Improve layout for narrow screens. - [#7524](https://github.com/flutter/devtools/pull/7524)
* Add error handling for missing schemes and domains - [#7559](https://github.com/flutter/devtools/pull/7559)

## VS Code Sidebar updates

* Added a DevTools section with a list of tools that are available without a debug
session. - [#7598](https://github.com/flutter/devtools/pull/7598)

## DevTools Extension updates

* Deprecate the `DevToolsExtension.requiresRunningApplication` field in favor of the
new optional `requiresConnection` field that can be added to an extension's `config.yaml`
file. - [#7611](https://github.com/flutter/devtools/pull/7611), [#7602](https://github.com/flutter/devtools/pull/7602)
* Detect extensions for all types of run targets in a package. - [#7533](https://github.com/flutter/devtools/pull/7533),
[#7535](https://github.com/flutter/devtools/pull/7535)


## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.35.0).
