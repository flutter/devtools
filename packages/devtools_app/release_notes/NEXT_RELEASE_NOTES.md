This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.28.3 release notes

The 2.28.3 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](https://docs.flutter.dev/tools/devtools/overview).

## General updates

* Added a link to the new "Dive in to DevTools" YouTube
[video](https://www.youtube.com/watch?v=_EYk-E29edo) in the bottom status bar. This
video provides a brief tutorial for each DevTools screen.
[#6554](https://github.com/flutter/devtools/pull/6554)

    ![Link to watch a DevTools tutorial video](images/watch_tutorial_link.png "Link to watch a DevTools tutorial video")

* Added a work around to fix copy button functionality in VSCode. [#6598](https://github.com/flutter/devtools/pull/6598)

* Enabled DevTools extensions when debugging a Dart entry point that is not
under `lib` (e.g. a unit test or integration test). Thanks to
[@bartekpacia](https://github.com/bartekpacia) for this change! -
[#6644](https://github.com/flutter/devtools/pull/6644)

## Inspector updates

TODO: Remove this section if there are not any general updates.

## Performance updates

* Disable the Raster Stats tool for the Impeller backend since it is not supported. [#6616](https://github.com/flutter/devtools/pull/6616)

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

## VS Code Sidebar updates

* When using VS Code with a light theme, the embedded sidebar provided by DevTools will now also show in the light
theme [#6581](https://github.com/flutter/devtools/pull/6581)

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.29.0).
