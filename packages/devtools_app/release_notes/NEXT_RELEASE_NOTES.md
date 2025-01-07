This is draft for future release notes, that are going to land on
[the Flutter website](https://docs.flutter.dev/tools/devtools/release-notes).

# DevTools 2.42.0 release notes

The 2.42.0 release of the Dart and Flutter DevTools
includes the following changes among other general improvements.
To learn more about DevTools, check out the
[DevTools overview](/tools/devtools/overview).

## General updates

* View licenses added to about dialog. - [#8610](https://github.com/flutter/devtools/pull/8610)

## Inspector updates

* The new inspector is enabled by default. This can be disabled in the inspector settings. - [#8650](https://github.com/flutter/devtools/pull/8650)
    ![Legacy inspector setting](images/legacy_inspector_setting.png "Legacy inspector setting")
* Selecting an implementation widget on the device while implementation widget's are hidden in the [new inspector's](https://docs.flutter.dev/tools/devtools/release-notes/release-notes-2.40.1#inspector-updates) does not show an error. - [#8625](https://github.com/flutter/devtools/pull/8625)
* Enabled auto-refreshes of the widget tree on hot-reloads and navigation events by default. This can be disabled in the inspector settings. - [#8646](https://github.com/flutter/devtools/pull/8646)
    ![Auto-refresh setting](images/inspector_auto_refresh_setting.png "Inspector auto-refresh setting")

## Full commit history

To find a complete list of changes in this release, check out the
[DevTools git log](https://github.com/flutter/devtools/tree/v2.42.0).
