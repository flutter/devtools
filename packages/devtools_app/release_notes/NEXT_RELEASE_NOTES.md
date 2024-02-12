This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.33.0 release notes

The 2.33.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](https://docs.flutter.dev/tools/devtools/overview).

## General updates

* Improved overall usability by making the DevTools UI more dense. This
significantly improves the user experience when using DevTools embedded in
an IDE. - [#7030](https://github.com/flutter/devtools/pull/7030)
* Removed the "Dense mode" setting. - [#7086](https://github.com/flutter/devtools/pull/7086)
* Added support for filtering with regular expressions in the Logging, Network, and CPU profiler
pages - [#7027](https://github.com/flutter/devtools/pull/7027)
* Add a DevTools server interaction for getting the DTD uri. - [#7054](https://github.com/flutter/devtools/pull/7054), [#7164](https://github.com/flutter/devtools/pull/7164)
* Enabled expression evaluation with scope for the web, allowing evaluation of inspected widgets. - [#7144](https://github.com/flutter/devtools/pull/7144)
* Update `package:vm_service` constraint to `^14.0.0`. - [#6953](https://github.com/flutter/devtools/pull/6953)

## Inspector updates

TODO: Remove this section if there are not any general updates.

## Performance updates

TODO: Remove this section if there are not any general updates.

## CPU profiler updates

TODO: Remove this section if there are not any general updates.

## Memory updates

TODO: Remove this section if there are not any general updates.

## Debugger updates

* Fixed off by one error causing profiler hits to be rendered on the wrong
lines. - [#7178](https://github.com/flutter/devtools/pull/7178)
* Improved contrast of line numbers when displaying code coverage hits in dark
mode. - [#7178](https://github.com/flutter/devtools/pull/7178)
* Improved contrast of profiling details when displaying profiler hits in dark
mode. - [#7178](https://github.com/flutter/devtools/pull/7178)
* Fixed syntax highlighting for comments when the source file uses `\r\n` line endings [#7190](https://github.com/flutter/devtools/pull/7190)

## Network profiler updates

TODO: Remove this section if there are not any general updates.

## Logging updates

TODO: Remove this section if there are not any general updates.

## App size tool updates

TODO: Remove this section if there are not any general updates.

## VS Code Sidebar updates

* Do not show DevTools release notes in the Flutter sidebar. - [#7166](https://github.com/flutter/devtools/pull/7166)

## DevTools Extension updates

* Fixed an issue with not detecting extensions for test files in
subdirectories. - [#7174](https://github.com/flutter/devtools/pull/7174)
* Add an example of creating an extension for a pure Dart package. - [#7196](https://github.com/flutter/devtools/pull/7196)

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.33.0).
