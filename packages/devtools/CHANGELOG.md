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
