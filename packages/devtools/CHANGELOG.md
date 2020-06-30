## 0.8.0+1
* Build with fix for canvas kit crasher

## 0.8.0
* Ship Flutter Web version of DevTools by default
* Update package:vm_service dependency to ^4.1.0

## 0.2.5 2020-05-07
* Persist connected app URI when switching to Flutter web version of DevTools [#1933](https://github.com/flutter/devtools/pull/1933)
* Fix CPU profiler bug where we were unintentionally mutating data [#1923](https://github.com/flutter/devtools/pull/1923)
* Add "Remove all breakpoints" functionality to debugger [#1914](https://github.com/flutter/devtools/pull/1914)

## 0.2.4+1 2020-05-05
* Memory Snapshot [#1885](https://github.com/flutter/devtools/pull/1885)
* Added new debugger page.
* Added new Network page.
* Add selected row to TreeTableState [#1795](https://github.com/flutter/devtools/pull/1795)
* Add an info / about dialog [#1772](https://github.com/flutter/devtools/pull/1772)
* Add banner message warnings and errors [#1764](https://github.com/flutter/devtools/pull/1764)
* Implement scroll-to-zoom and alt+scroll for flame charts [#1747](https://github.com/flutter/devtools/pull/1747)
* Add sorting functionality to flutter tables [#1738](https://github.com/flutter/devtools/pull/1738)
* Enable toggling http logging from Timeline. [#1688](https://github.com/flutter/devtools/pull/1688)
* Merge frame-based timeline and full timeline [#1712](https://github.com/flutter/devtools/pull/1712)
* Stop skipping duplicate trace events in full timeline processor. [#1704](https://github.com/flutter/devtools/pull/1704)
* Fix bug causing import to fail when DevTools is not connected to an app [#1703](https://github.com/flutter/devtools/pull/1703)
* Update package:vm_service dependency to ^4.0.0

## 0.2.3 2020-03-03
* Disable Q1 DevTools survey - postponing until Q2 [#1695](https://github.com/flutter/devtools/pull/1695)
* Fix async timeline event rendering bug [#1690](https://github.com/flutter/devtools/pull/1690)
* Update package:vm_service dependency to ^3.0.0 [#1696](https://github.com/flutter/devtools/pull/1696)

## 0.2.2 2020-02-28
* Remove cpu profiling timeout [#1683]((https://github.com/flutter/devtools/pull/1683)
* Prep for Q1 DevTools survey [#1574](https://github.com/flutter/devtools/pull/1574)
* Use ExtentDelegateListView for flame chart rows [#1676](https://github.com/flutter/devtools/pull/1676)
* Make the layout explorer more null safe [#1681](https://github.com/flutter/devtools/pull/1681)
* Store survey data by quarter tags [#1660](https://github.com/flutter/devtools/pull/1660)
* Don't check for debugDidSendFirstFrameEvent when adding service extensions for Dart VM apps [#1670](https://github.com/flutter/devtools/pull/1670)
* Restructure HTTP code for shared use with Timeline and check http logging availability [#1668](https://github.com/flutter/devtools/pull/1668)
* Debugger file picker [#1652](https://github.com/flutter/devtools/pull/1652)
* Port CPU bottom up table to Flutter [#1659](https://github.com/flutter/devtools/pull/1659)
* Add extent_delegate_list supporting fast lists where each element has a known custom extent [#1646](https://github.com/flutter/devtools/pull/1646)
* Workaround VM Regression where first heap sample's rss value is null [#1662](https://github.com/flutter/devtools/pull/1662)
* Remove the dependency on package:recase [#1656](https://github.com/flutter/devtools/pull/1656)
* Polish SafeAccess extension methods to use getters and support Iterable [#1647](https://github.com/flutter/devtools/pull/1647)
* Updated mp_chart to 0.1.7 [#1654](https://github.com/flutter/devtools/pull/1654)
* Introduce a view for showing the source of a script in Flutter with the monospaced font [#1649](https://github.com/flutter/devtools/pull/1649)
* Load imported timeline files [#1644](https://github.com/flutter/devtools/pull/1644)
* Introduce an interface for the notification service for use in controller logic [#1645](https://github.com/flutter/devtools/pull/1645)
* Fix null error in timeline page [#1641](https://github.com/flutter/devtools/pull/1641)
* Stop disposing Notifications and Controllers from import_export [#1640](https://github.com/flutter/devtools/pull/1640)
* Remove dependency on package:flutter_widgets [#1636](https://github.com/flutter/devtools/pull/1636)
* Created CLI to write Flutter application memory profile statistics to a JSON file [#1628](https://github.com/flutter/devtools/pull/1628)
* Improve the error reporting on connection issues [#1635](https://github.com/flutter/devtools/pull/1635)
* Add import / export functionality and support drag-and-drop [#1631](https://github.com/flutter/devtools/pull/1631)
* Fix timeline bug throwing error for empty recording [#1630](https://github.com/flutter/devtools/pull/1630)
* Make the rollback help text consistent with the other commands [#1634](https://github.com/flutter/devtools/pull/1634)
* Introduce a rollback command that pulls an old devtools build and preps it for release [#1617](https://github.com/flutter/devtools/pull/1617)
* Add zoomable timeline grid and timestamps to flame chart [#1624](https://github.com/flutter/devtools/pull/1624)
* Use registerServiceExtension method instead of eval directly in layout explorer [#1531](https://github.com/flutter/devtools/pull/1531)
* Factor zoom level into flame chart node selection logic [#1623](https://github.com/flutter/devtools/pull/1623)
* Update to support devtools_server [#1622](https://github.com/flutter/devtools/pull/1622)
* Flame chart zoom and navigation with WASD keys [#1611](https://github.com/flutter/devtools/pull/1611) 
* Updated to use package:devtools_shared [#1620](https://github.com/flutter/devtools/pull/1620))
* Initial devtools_shared package [#1619](https://github.com/flutter/devtools/pull/1619)
* Remove --trace-systrace flag from MacOs and Linux configs [#1614](https://github.com/flutter/devtools/pull/1614)

## 0.1.15 2020-02-07
* Fix a stack overflow error that was caused by a change in Dart's RTI implementation [#1615](https://github.com/flutter/devtools/pull/1615).
* Hide annotations that Flutter re-exports [#1606](https://github.com/flutter/devtools/pull/1606)
* Update package:devtools_server dependency to 0.1.13 or newer [#1603](https://github.com/flutter/devtools/pull/1603)
* Update package:sse dependency to 3.1.2 or newer [#1601](https://github.com/flutter/devtools/pull/1601)

## 0.1.14 2020-02-03
* Added collecting of Android Debug Bridge (adb) Java memory information see [PR](https://github.com/flutter/devtools/pull/1553).
* Added multiple charts to memory profiling (Dart VM and Java memory).
* Added display interval e.g., 1 minute, 5 minutes, 10 minutes for memory charts.
* More succinct memory detail marker (pop-up) for data points of a particular timestamp.
* Graceful resize buttons and drop-downs in memory profile for narrower windows.
* Updated exported JSON format both Dart VM and ADB memory information.
* Added timeline slider, to memory profile, for temporal navigation in charts.
* Added ‘Clear’ button, to memory profile, throws away all collected live data.
* Fix a number of charting bugs NaN, INF problems, axis scales, etc.
* Support saving and loading memory profile data.
* Add Track Widget Builds toggle to Timeline.
* Fix issues with async trace event rendering in Timeline.
* Add timing and id information in Timeline event summary.
* Improve hint text on connect screen.
* Update package:vm_service dependency to ^2.2.0.

## 0.1.13 - 2019-12-10
* Fix crash opening macOS desktop apps in DevTools.
* Enable layout explorer.
* Hide legacy page content in the flutter version of DevTools.
* Fix offline import bug in Timeline.
* Use published version of mp_chart package.

## 0.1.12 - 2019-12-06
* Enable testing the alpha version of DevTools written in Flutter. Click the "beaker" icon in the upper-right to launch DevTools in Flutter.
* Fix a regression that showed an inaccurate error on the connect screen.
* Fix bug causing async events with the same name to overlap each other in the Timeline.
* Include previously omitted args in Timeline event summary.
* Include "connected events" in the Timeline event summary, which are created via the dart:developer TimelineTask api.
* Reset debugger search bar on hot reload.
* Check for a debug service extension instead of using eval to distinguish between debug and profile builds.
* Depend on the latest `package:sse`.

## 0.1.11 - 2019-11-08
* Add full timeline mode with support for async and recorded tracing.
* Add event summary section that shows metadata for non-ui events on the Timeline page.
* Enable full timeline for Dart CLI applications.
* Fix a message manager bug.
* Fix a bug with processing CPU profile responses.
* Reduce race conditions in integration tests.

## 0.1.10 - 2019-10-18
* Change wording of DevTools survey prompt.

## 0.1.9 - 2019-10-17
* Launched the Q3 DevTools Survey.
* Bug fixes related to layouts and logging.
* Update to use latest devtools_server 0.1.12.
* Remove usage of browser LocalStorage, previously used to store the user's answer to collect or not collect Analytics.
* Analytic's properties (firstRun, enabled) are now stored in local file ~/.devtools controlled by the devtools_server.
* Now devtools_app will request and set property values, in ~/.devtools, via HTTP requests to the devtools_server.
* Store survey properties on whether the user has answered or dismissed a survey in the ~/.devtools file too.

## 0.1.8 - 2019-10-01
* Query a flutter isolate for the target frame rate (e.g. 60FPS vs 120FPS). Respect this value in the Timeline.
* Polish import / export flow for Timeline.
* Depend on latest `package:devtools_server`.

## 0.1.7 - 2019-09-09
* Fix bug with profile mode detection.
* Enable expand all / collapse to selected functionality in the inspector (available in Flutter versions 1.10.1 or later).
* Fix analytics bug for apps running in profile mode.
* Fix bug in memory experiment handling.
* Hide Dart VM flags when the connected app is not running on the Dart VM (web apps).
* Former "Settings" screen is now the "Info" screen - updated icon accordingly.
* Various CSS fixes.
* Code health improvements.

## 0.1.6 - 2019-09-04
* Add a page to show Flutter version and Dart VM flags details.
* Add settings dialog to memory page that supports filtering snapshots and enabling experiments.
* Various css fixes.
* CSS polish for cursors, hover, and misc.
* Use frame time in CPU profile unavailable message.
* Fixes to our splitter control.
* Rev to the latest version of `package:vm_service`.
* Remove the dependency on `package:mockito`.
* Remove the dependency on `package:rxdart`.
* Support `sse` and `sses` schemes for connection with a running app.
* Address an npe in the memory page.
* Polish button collapsing for small screen widths.
* Adjust some of the logging flutter.error presentation.
* Fix thread name bug.
* Support Ansi color codes in logging views.
* Add keyboard navigation to the inspector tree view.
* Enable structured errors by default.
* Fix NPE in the Debugger.
* Improve testing on Windows.

## 0.1.5 - 2019-08-05
* Support expanding or collapsing all values in the Call Tree and Bottom Up views (parts of the CPU profiler).
* Support touchscreen scrolling and selection in flame charts.
* Display structured error messages in the Logging view when "show structured errors" is enabled.
* Search and filter dialogs are now case-insensitive.
* Link to Dart DevTools documentation from connect screen.
* Disable unsupported DevTools pages for Dart web apps.
* Debugger dark mode improvements.

## 0.1.4 - 2019-07-19
* Add Performance page. This has a traditional CPU profiler for Dart applications.
* Add ability to specify the profile granularity for the CPU profiler.
* Bug fixes for DevTools tables, memory page, and cpu profiler.

## 0.1.3 - 2019-07-11
* Link to new flutter.dev hosted DevTools documentation.
* Inspector UI improvements.

## 0.1.2 - 2019-07-01
* Add Call Tree and Bottom Up views to CPU profiler.
* Pre-fetch CPU profiles so that we have profiling information for every frame in the timeline.
* Trim Mixins from class name reporting in the CPU profiler.
* Add searching for a particular class from all active classes in a Snapshot. After a snapshot, use the search button, located to left of snapshot button (or the shortcut CTRL+f ), to find and select the class in the classes list.
* Add ability to find which class and field hold a reference to the current instance.  Hovering on an instance's allocation icon (right-most side of the instance).  Clicking on a class/field entry in the hover card will locate that particular class instance that has a reference to the original instance being hovered.
* Expose hover card navigation via a memory navigation history areas (group of links below the classes/instances lists).
* Allow DevTools feedback to be submitted when DevTools is not connected to an app.
* Support URL encoded urls in the connection dialog.
* Add error handling for analytics.
* Cleanup warning message presentation.
* Bug fixes and improvements.

## 0.1.1 - 2019-05-30
* Make timeline snapshot format compatible with trace viewers such as chrome://tracing.
* Add ability to import timeline snapshots via drag-and-drop.
* Memory instance viewer handles all InstanceKind lists.
* CPU profiler bug fixes and improvements.

## 0.1.0 - 2019-05-02
* Expose functionality to export timeline trace and CPU profiles.
* Add "Clear" button to the timeline page.
* CPU profiler bug fixes and improvements.
* Inspector polish bug fixes. Handle very deep inspector trees and only show expand-collapse arrows on tree nodes where needed.
* Fix case where error messages remained on the startup screen after the error had been fixed.
* Add ability to inspect an instance of a memory object in the memory profiler page after a snapshot of active memory objects.
* First time DevTools is launched, prompt with an opt-in dialog to report DevTools usage statistics and crash reports of DevTools to Google.

## 0.0.19 - 2019-05-01
* Update DevTools server to better handle failures when launching browsers.
* Support additional formats for VM service uris.
* Link to documentation from --track-widget-creation warning in the Inspector.

## 0.0.18 - 2019-04-30
* Fix release bug (0.0.17-dev.1 did not include build folder).
* Add CPU profiler (preview) to timeline page.
* CPU flame chart UI improvements and bug fixes.
* Bug fixes for DevTools on Windows.
* DevTools server released with support for launching DevTools in Chrome.
* Dark mode improvements.

## 0.0.16 - 2019-04-17
* Reduce the minimum Dart SDK requirements for activating DevTools to cover Flutter v1.2.1 (Dart v2.1)

## 0.0.15 - 2019-04-16
* Warn users when they should be using a profile build of their application instead of a debug build.
* Warn users using Microsoft browsers (IE and Edge) that they should be using Chrome to run DevTools.
* Dark mode improvements.
* Open scripts in the debugger using ctrl + o.

## 0.0.14 - 2019-03-26
* Dark mode is ready to use, add ```&theme=dark``` at the end of the URI used to open the DevTool in Chrome. We look forward to your feedback.
* Added event timeline to memory profiler to track DevTool's Snapshot and Reset events.
* Timeline CPU renamed to UI, janky defined as UI duration + GPU duration > 16 ms.
* Timeline frame chart removed 8 ms highwater line, only 16 ms highwater line, display 2 traces ui/gpu (instead of 4). Janky frames will have a red glow.
* Flame chart colors use a different set of palettes and timeline is sticky.
* Warn users when they are using an unsupported browser.
* Properly disable features that aren't supported for the connected application.
* Fix screens for different widths.
## 0.0.13 - 2019-03-15
* Dark mode, still being polished, is available.  Add ```&theme=dark``` at the end of URI used to open DevTools in the Chrome browser.
### Memory
* Added showing GCs on the timeline and leak detection.
### Timeline
* Fix bugs when events were received out of order.

## 0.0.1
- initial (pre-release) release

<!--
List of possible sections to use for areas that have changed.
### Documentation
### Debugger
### Inspector
### Logging
### Memory
### Table
### Timeline
-->
