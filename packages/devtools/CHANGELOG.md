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
