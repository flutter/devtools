## 0.0.15 - Date TBD
* Warn users when they should be using a profile build of their application instead of a debug build.

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
