## 2.4.0
* Fix isEmbedded bug [#3177](https://github.com/flutter/devtools/pull/3177)
* Move performance tests out of package:devtools_testing [#3173](https://github.com/flutter/devtools/pull/3173)
* Refactor devtools_server to minimize transitive deps [#3164](https://github.com/flutter/devtools/pull/3164)
* Ignore a reference to a deprecated item [#3166](https://github.com/flutter/devtools/pull/3166)
* Surface extra field in RemoteDiagnosticsNode [#3137](https://github.com/flutter/devtools/pull/3137)
* Perform more normalization of the input service uri [#3160](https://github.com/flutter/devtools/pull/3160)
* Make our toast UI more compact [#3159](https://github.com/flutter/devtools/pull/3159)
* Update version to 2.3.3-dev.1 [#3157](https://github.com/flutter/devtools/pull/3157)
* Convert the repo tool lib to null safety [#3155](https://github.com/flutter/devtools/pull/3155)
* Show the event summary view for UI events in the performance page [#3154](https://github.com/flutter/devtools/pull/3154)
* Do not fetch CPU profiles in offline mode [#3152](https://github.com/flutter/devtools/pull/3152)
* Add dense mode for inspector [#3149](https://github.com/flutter/devtools/pull/3149)
* Some cleanup to the CLI UI [#3129](https://github.com/flutter/devtools/pull/3129)
* Fix a couple null issues in the cpu profiler [#3142](https://github.com/flutter/devtools/pull/3142)
* Add a TODO for rich tooltips in the Flutter frames chart [#3140](https://github.com/flutter/devtools/pull/3140)
* Handle pre-release versions in Flutter version parsing and comparison [#3134](https://github.com/flutter/devtools/pull/3134)
* Add an Error banner with a link to documentation when shader jank is detected [#3128](https://github.com/flutter/devtools/pull/3128)
* Surface shader time per frame in the Performance page [#3125](https://github.com/flutter/devtools/pull/3125)
* Disable CPU profile controls when recording [#3127](https://github.com/flutter/devtools/pull/3127)
* Updated buildViewportChrome [#3124](https://github.com/flutter/devtools/pull/3124)
* Remove references to the widget transformer's parameterLocations field [#3120](https://github.com/flutter/devtools/pull/3120)
* Cache CPU profiles for selected frames [#3121](https://github.com/flutter/devtools/pull/3121)
* Update Dart favicon to match elsewhere [#3119](https://github.com/flutter/devtools/pull/3119)
* Added the padding to the Details Tree View [#3108](https://github.com/flutter/devtools/pull/3108)
* Fix bug where you could trigger simultaneous connects by accidentally clicking or pressing return twice [#3114](https://github.com/flutter/devtools/pull/3114)
* Start of refactoring hovercards [#3117](https://github.com/flutter/devtools/pull/3117)
* Add a clear method to history_manager [#3118](https://github.com/flutter/devtools/pull/3118)
* Optimize _isOperator test [#3115](https://github.com/flutter/devtools/pull/3115)
* Avoid NPE in the layout explorer [#3116](https://github.com/flutter/devtools/pull/3116)
* Fix inspector on flutter web [#3112](https://github.com/flutter/devtools/pull/3112)
* Switch to `flutter pub get` and update canvaskit version [#3096](https://github.com/flutter/devtools/pull/3096)
* Add a loading message when loading app size data from file paths [#3109](https://github.com/flutter/devtools/pull/3109)
* Fix bug with including html import in desktop app [#3111](https://github.com/flutter/devtools/pull/3111)
* Improve scrolling / zooming behavior in flame charts [#3107](https://github.com/flutter/devtools/pull/3107)
* Added the autofocus to debug Filter TextField [#3104](https://github.com/flutter/devtools/pull/3104)
* Fix a null pointer exception if keypress fires before app is initialized [#3106](https://github.com/flutter/devtools/pull/3106)
* Catch any unhandled exceptions in devtools and report via our analytics channel [#3100](https://github.com/flutter/devtools/pull/3100)
* Replace reference to dartlang.org with dart.dev [#3101](https://github.com/flutter/devtools/pull/3101)
* Add padding for go to line dialog [#3093](https://github.com/flutter/devtools/pull/3093)

## 2.3.2
* Hover fixes [3065](https://github.com/flutter/devtools/pull/3065)
* Fix a bug with app initialization [3067](https://github.com/flutter/devtools/pull/3067)
* Stop checking flutter version for connected app in flutter web apps [3066](https://github.com/flutter/devtools/pull/3066)
* Fix bug with adding flutter version to exports [3060](https://github.com/flutter/devtools/pull/3060)
* Show LegacyPerformanceScreen or PerformanceScreen based on the current flutter version [3056](https://github.com/flutter/devtools/pull/3056)
* Use font size from IDE theme [3054](https://github.com/flutter/devtools/pull/3054)
* Lighten the area pane header color for light theme [3051](https://github.com/flutter/devtools/pull/3051)
* Fix title color for light theme. [3048](https://github.com/flutter/devtools/pull/3048)
* Polish UI in the debugger page [3052](https://github.com/flutter/devtools/pull/3052)
* Fix flutter frame coloring to reflect which part of the frame is janky. [3049](https://github.com/flutter/devtools/pull/3049)
* Handle getObject issues during autocomplete [3046](https://github.com/flutter/devtools/pull/3046)
* Improve eval autocomplete [3045](https://github.com/flutter/devtools/pull/3045)
* Add "Load all CPU samples" button to the CPU profiler [2943](https://github.com/flutter/devtools/pull/2943)
* Migrate ansi_up to null safety [3027](https://github.com/flutter/devtools/pull/3027)
* Migrate devtools_server to null safety [3009](https://github.com/flutter/devtools/pull/3009)
* Migrate package:codicon to null safety. [3026](https://github.com/flutter/devtools/pull/3026)
* Use selectable text everywhere in Network page [3036](https://github.com/flutter/devtools/pull/3036)
* CPU profiler search: support regexp and match on stack frame urls [3035](https://github.com/flutter/devtools/pull/3035)
* Eval Console Autocomplete [3013](https://github.com/flutter/devtools/pull/3013)
* Rank skia shader events first in the performance page timeline [#3083](https://github.com/flutter/devtools/pull/#083)
* Support multi-line eval output [#3086](https://github.com/flutter/devtools/pull/3086)
* Update vm_service dependency. [#3082](https://github.com/flutter/devtools/pull/3082)

## 2.2.4
* Fix bug in devtools_server by calling proper vm service API [#3040](https://github.com/flutter/devtools/pull/3040)

## 2.2.3
* Enable the provider screen [#2998](https://github.com/flutter/devtools/pull/2998) [#3010](https://github.com/flutter/devtools/pull/3010) [#3006](https://github.com/flutter/devtools/pull/23006) [#2992](https://github.com/flutter/devtools/pull/2992)
* Support filtering CPU profiles by UserTags [#2988](https://github.com/flutter/devtools/pull/2988)
## 2.2.2
* Throw RPCError when invoking `getSourceReport` in profile mode [#2986](https://github.com/flutter/devtools/pull/2986)

## 2.2.1
* Temporarily disable the provider screen. [#2970](https://github.com/flutter/devtools/pull/2970)
* Refactor CPU profiler screen controls into their own widgets [#2969](https://github.com/flutter/devtools/pull/2969)

## 2.2.0
* Add richer auto-complete for use in an expression evaluator. [#2962](https://github.com/flutter/devtools/pull/2962)
* Refactor Debugger history view into HistoryViewport widget [#2957](https://github.com/flutter/devtools/pull/2957)
* Improve search and build performance in flame charts [#2959](https://github.com/flutter/devtools/pull/2959)
* Add tab for inspecting the state of package:provider [#2851](https://github.com/flutter/devtools/pull/2851)
* Add source paths to CPU profile bottom up and call tree tables [#2956](https://github.com/flutter/devtools/pull/2956)
* Add support for system isolates to isolate selector while in VM developer mode [#2947](https://github.com/flutter/devtools/pull/2947)
* Do not log eval error for _connectedToProfileBuild check [#2954](https://github.com/flutter/devtools/pull/2954)
* Add a secondary sort column to tables and fix logging page sorting bug. [#2940](https://github.com/flutter/devtools/pull/2940)
* Improve debug hover [#2936](https://github.com/flutter/devtools/pull/2936)
* Add search in file functionality to the debugger code view. [#2931](https://github.com/flutter/devtools/pull/2931)
* Add report feedback button to top level actions in DevTools [#2925](https://github.com/flutter/devtools/pull/2925)
* Refactor areaPaneHeader into a widget [#2924](https://github.com/flutter/devtools/pull/2924)
* Add network profiler response image preview [#2922](https://github.com/flutter/devtools/pull/2922)
* Support passing keypresses up to IDEs to enable shortcut keys when embedded DevTools has focus [#2872](https://github.com/flutter/devtools/pull/2872)
* Render GC and non-ui/non-raster events in their respective thread groups [#2917](https://github.com/flutter/devtools/pull/2917)
* Fix issue where first build of the VM Tools status bar would cause a null pointer exception [#2905](https://github.com/flutter/devtools/pull/2905)
* [network_request_inspector_views] remove maxLines from SelectableText widgets [#2912](https://github.com/flutter/devtools/pull/2912)
* Matching landing page title to subheadings [#2891](https://github.com/flutter/devtools/pull/2891)
* Use "fuzzy match" in debugger libraries search [#2904](https://github.com/flutter/devtools/pull/2904)
* Larger evaluation hover overlay [#2908](https://github.com/flutter/devtools/pull/2908)
* Fix scrolling with with drag [#2907](https://github.com/flutter/devtools/pull/2907)
* Go To Line Number Option [#2902](https://github.com/flutter/devtools/pull/2902)
* Fix "Count" text getting cut off when sorting [#2898](https://github.com/flutter/devtools/pull/2898)
* Add issueTrackerLink method to DevToolsExtensionPoints [#2901](https://github.com/flutter/devtools/pull/2901)
* Change to calling upgrade [#2897](https://github.com/flutter/devtools/pull/2897)
* Added stacked and hover card trace color/dash. [#2889](https://github.com/flutter/devtools/pull/2889)
* Add framework for internal features and add debugger menu options hook. [#2887](https://github.com/flutter/devtools/pull/2887)
* Polish to debugger actions. [#2886](https://github.com/flutter/devtools/pull/2886)
* Use a single scroll offset for all flame chart painters instead of having them all listen for offset changes independently [#2884](https://github.com/flutter/devtools/pull/2884)
* Fix focus management in timeline flame chart [#2883](https://github.com/flutter/devtools/pull/2883)
* Support copying file in the debugger [#2875](https://github.com/flutter/devtools/pull/2875)
* Add previous/next event in thread buttons to the Timeline [#2878](https://github.com/flutter/devtools/pull/2878)
* Auto expand search results [#2877](https://github.com/flutter/devtools/pull/2877)
* Fix a couple bugs with flame chart styling and zoom. [#2873](https://github.com/flutter/devtools/pull/2873)

## 2.1.1
* Set the correct dart:io service extension protocol version for the new HTTP profiler logic [#2867](https://github.com/flutter/devtools/pull/2867)

## 2.1.0
* Memory legends cleanup [#2833](https://github.com/flutter/devtools/pull/2833)
* Update network profiler to support dart:io HTTP profiling service extensions [#2839](https://github.com/flutter/devtools/pull/2839)
* Use widgets for flame chart group labels instead of custom painters [#2837](https://github.com/flutter/devtools/pull/2837)
* Add EvalOnDartLibrary utilities [#2807](https://github.com/flutter/devtools/pull/2807)
* Remove Android Memory CTA if not connected to an Android app[#2799](https://github.com/flutter/devtools/pull/2799)
* Fixed location of exported memory stat JSON file. [#2795](https://github.com/flutter/devtools/pull/2795)
* Increase size of total time column in CPU profiler [#2814](https://github.com/flutter/devtools/pull/2814)
* Fix bugs with DevTools title and move title code to separate file [#2809](https://github.com/flutter/devtools/pull/2809)
* Fix some flame chart scrolling bugs [#2808](https://github.com/flutter/devtools/pull/2808)
* Cleanup for performance settings dialog [#2801](https://github.com/flutter/devtools/pull/2801)
* Fix frame timing issue in performance page [#2802](https://github.com/flutter/devtools/pull/2802)
* Improve file history picker UX [#2785](https://github.com/flutter/devtools/pull/2785)
* Improve file picker UX [#2784](https://github.com/flutter/devtools/pull/2784)
* Add show/hide gc button in memory screen[#1089](https://github.com/flutter/devtools/pull/1089) [#2787](https://github.com/flutter/devtools/pull/2787)
* Show correct mouse cursor for splitters [#2783](https://github.com/flutter/devtools/pull/2783)
* Clean up - fix overflow error and some text styles [#2782](https://github.com/flutter/devtools/pull/2782)
* Add option to load offline file from landing screen [#2762](https://github.com/flutter/devtools/pull/2762)
* Evaluation HoverCard [#2746](https://github.com/flutter/devtools/pull/2746), [#2810](https://github.com/flutter/devtools/pull/2810), [#2831](https://github.com/flutter/devtools/pull/2831)
* Reworked UX for tracking call stack. [#2846](https://github.com/flutter/devtools/pull/2846)

## 2.0.0+4
* Upgrade DevTools dependencies for http_multi_server [#2838](https://github.com/flutter/devtools/pull/2838)

## 2.0.0+3
* Upgrade DevTools dependencies for usage and shelf_static [#2836](https://github.com/flutter/devtools/pull/2836)

## 2.0.0+2
* Upgrade DevTools dependencies [#2818](https://github.com/flutter/devtools/pull/2818)

## 2.0.0+1
* Upgrade dependencies for `args`, `meta`, `path`, and `pedantic` [#2817](https://github.com/flutter/devtools/pull/2817)

## 2.0.0
* Add support for older VMs, cleanup memory filter dialog and retained size [#2752](https://github.com/flutter/devtools/pull/2752)
* Add memory allocations tracked indicator and polish event icons for track and reset [#2751](https://github.com/flutter/devtools/pull/2751)
* Memory page cleanup and hints [#2749](https://github.com/flutter/devtools/pull/2749)
* Add support for serving a custom DevTools build [#2748](https://github.com/flutter/devtools/pull/2748)
* Add temporary workaround for flutter engine bug [#2747](https://github.com/flutter/devtools/pull/2747)
* Flame chart scrolling polish [#2745](https://github.com/flutter/devtools/pull/2745)
* Add selection styling to network table and cleanup table selection style [#2744](https://github.com/flutter/devtools/pull/2744)
* Make debugger gutter background color extend to bottom of view [#2743](https://github.com/flutter/devtools/pull/2743)
* Cleanup memory icons to be sharper [#2742](https://github.com/flutter/devtools/pull/2742)
* Memory page UX polish [#2740](https://github.com/flutter/devtools/pull/2740)
* Move codicon.ttf file as part of publish script to include it in build [#2739](https://github.com/flutter/devtools/pull/2739)
* Initialize framework before initializing PreferencesController [#2737](https://github.com/flutter/devtools/pull/2737)
* Fix another lifecycle issue [#2736](https://github.com/flutter/devtools/pull/2736)
* New UX look for memory snapshot and allocations [#2735](https://github.com/flutter/devtools/pull/2735)
* Fix Memory panel hover overlay leak [#2734](https://github.com/flutter/devtools/pull/2734)
* Bump version to dev version [#2733](https://github.com/flutter/devtools/pull/2733)
* Fix lifecycle management issues with disconnecting and reconnecting to apps [#2732](https://github.com/flutter/devtools/pull/2732)
* Update CanvasKit release to 0.24.0 to match current version used by engine [#2731](https://github.com/flutter/devtools/pull/2731)
* Remove thread information on Isolates page [#2730](https://github.com/flutter/devtools/pull/2730)
* Fixed memory heap snapshot semantics [#2728](https://github.com/flutter/devtools/pull/2728)
* Use new VM API for allocation trace [#2720](https://github.com/flutter/devtools/pull/2720)
* Support latest VMService version [#2719](https://github.com/flutter/devtools/pull/2719)
* Remove inspector error indicators and render error message inline [#2717](https://github.com/flutter/devtools/pull/2717)
* Fixed hover card in memory events chart [#2716](https://github.com/flutter/devtools/pull/2716)
* Use lazy list for network requests table [#2715](https://github.com/flutter/devtools/pull/2715)
* Delete code to fallback to the dart:html version of the app [#2713](https://github.com/flutter/devtools/pull/2713)
* Auto-populate call stack frames in the debugger [#2711](https://github.com/flutter/devtools/pull/2711)
* Request focus from flame chart keyboard listener [#2710](https://github.com/flutter/devtools/pull/2710)
* Fix inspector scrollbars [#2709](https://github.com/flutter/devtools/pull/2709)
* Fix noisy assertion error in timeline processing code [#2708](https://github.com/flutter/devtools/pull/2708)
* Disable error badging for the logging screen [#2707](https://github.com/flutter/devtools/pull/2707)
* Fixed memory search, auto-complete, and added tests [#2705](https://github.com/flutter/devtools/pull/2705)
* Fix tree table scrolling issues [#2702](https://github.com/flutter/devtools/pull/2702)
* Prevent most caught exceptions when constraints are unavailable [#2700](https://github.com/flutter/devtools/pull/2700)
* Run flutter format [#2699](https://github.com/flutter/devtools/pull/2699)
* Flex layout polish [#2698](https://github.com/flutter/devtools/pull/2698)
* Handle bad source input during syntax highlighting [#2696](https://github.com/flutter/devtools/pull/2696)
* Use VS code debugging icons in debugger [#2693](https://github.com/flutter/devtools/pull/2693)
* Fix bug in inspector for expand / collapse button display [#2692](https://github.com/flutter/devtools/pull/2692)
* Add persistent scrollbars to tables [#2689](https://github.com/flutter/devtools/pull/2689)
* Add a help dialog to the flame chart describing how to navigate and zoom within the chart [#2686](https://github.com/flutter/devtools/pull/2686)
* Fix a bug with debugger stepping buttons state [#2683](https://github.com/flutter/devtools/pull/2683)
* Rev SSE version [#2681](https://github.com/flutter/devtools/pull/2681)
* Fix lifecycle bug in network page [#2680](https://github.com/flutter/devtools/pull/2680)
* Add vertical scrollbar to flame charts [#2678](https://github.com/flutter/devtools/pull/2678)
* Add floating debugger controls to non-debugging pages when app is paused [#2676](https://github.com/flutter/devtools/pull/2676)
* Revert auto-selection of the inspector root widget as it causes the cursor location to change in IDEs [#2675](https://github.com/flutter/devtools/pull/2675)
* Add scrollbars to inspector views [#2671](https://github.com/flutter/devtools/pull/2671)
* Prevent SelectableText widgets in the debugger code view from scrolling [#2670](https://github.com/flutter/devtools/pull/2670)
* Added support for expandable object inspection in the debugger console [#2666](https://github.com/flutter/devtools/pull/2666)
* Support selection within the TextView and fix bug showing pause location [#2665](https://github.com/flutter/devtools/pull/2665)
* Stop using rounded and sharp icons [#2659](https://github.com/flutter/devtools/pull/2659)

## 0.9.7+2
* Fix issue where DevTools would fail to connect to an application with no DDS instance [#2650](https://github.com/flutter/devtools/pull/2650)

## 0.9.7
* Button cleanup and polish [#2645](https://github.com/flutter/devtools/pull/2645)
* Make layout explorer the default tab in the inspector [#2644](https://github.com/flutter/devtools/pull/2644)
* Added settings dialog for memory page [#2637](https://github.com/flutter/devtools/pull/2637)
* Bundle canvaskit with the release binary so that DevTools can be used without internet [#2634](https://github.com/flutter/devtools/pull/2634)
* Add support for visualizing fixed layouts in the layout explorer [#2633](https://github.com/flutter/devtools/pull/2633)
* Listen for logs with event history in logging page and error badge manager [#2629](https://github.com/flutter/devtools/pull/2629)
* Add app events, extension events, and chart selection hover card to live memory view [#2605](https://github.com/flutter/devtools/pull/2605)
* Correctly process large HTTP responses in network profiler [#2602](https://github.com/flutter/devtools/pull/2602)
* Fallback to port 0 if we cannot connect the DevTools server to ports 9100+ [#2600](https://github.com/flutter/devtools/pull/2600)
* Add tooltips to CPU profiler column titles [#2599](https://github.com/flutter/devtools/pull/2599)
* Add timeline grid to CPU Profiler flame chart [#2593](https://github.com/flutter/devtools/pull/2593)
* Migrate to new material buttons [#2592](https://github.com/flutter/devtools/pull/2592)

## 0.9.6+3
* Support null safe `package:intl` version `>=0.17.x`.

## 0.9.6+2
* Support null safe `package:vm_service` version `>=6.x.x`.

## 0.9.6+1
* Fallback to port 0 if we cannot connect the DevTools server to ports 9100-9109 #2600

## 0.9.6
* Remove use of Flutter service worker [#2586](https://github.com/flutter/devtools/pull/2586)
* Badge performance tab when UI jank is detected and add a setting to enable/disable this functionality. [#2580](https://github.com/flutter/devtools/pull/2580)
* Badge inspector tab for structured inspector errors (Flutter.error) [#2576](https://github.com/flutter/devtools/pull/2576)
* Badge the Network tab when we receive failed network requests. [#2567](https://github.com/flutter/devtools/pull/2567)
* Badge logging page with error counts from logs and stderr [#2566](https://github.com/flutter/devtools/pull/2566)
* Add scrollbar to flutter frames chart [#2565](https://github.com/flutter/devtools/pull/2565)
* Rename "Timeline" page to "Performance" and populate CPU profile on frame selection [#2563](https://github.com/flutter/devtools/pull/2563)
* Rename "Performance" page to "CPU profiler" [#2562](https://github.com/flutter/devtools/pull/2562)
* Support truncated frames with a corresponding `SHOW ALL` button for faster flutter web stepping [#2545](https://github.com/flutter/devtools/pull/2545)
* Better x-axis labeling on the memory page [#2539](https://github.com/flutter/devtools/pull/2539)
* Add VM Tools screen with initial VM and Isolate statistics tabs [#2499](https://github.com/flutter/devtools/pull/2499)

## 0.9.5
* Add padding between columns and add minWidth for flexible columns. [#2526](https://github.com/flutter/devtools/pull/2526)
* Fix import bug. [#2528](https://github.com/flutter/devtools/pull/2528)
* Support loading app size files from query parameters and local storage [#2510](https://github.com/flutter/devtools/pull/2510)
* Remove use of mp_flutterchart and use new charting subsystem. [#2517](https://github.com/flutter/devtools/pull/2517)
* Fix null error in service manager [#2515](https://github.com/flutter/devtools/pull/2515)
* Expose information about oversized images [#2509](https://github.com/flutter/devtools/pull/2509)
* Fix race condition in service_manager. [#2501](https://github.com/flutter/devtools/pull/2501)
* Url and query param parsing cleanup [#2502](https://github.com/flutter/devtools/pull/2502)
* Add CenteredCircularProgressIndicator helper widget. [#2508](https://github.com/flutter/devtools/pull/2508)
* Add search and filter to the logging page; refactor filter code [#2493](https://github.com/flutter/devtools/pull/2493)
* Add a lower bound sdk constraint [#2511](https://github.com/flutter/devtools/pull/2511)
* New chart [#2498](https://github.com/flutter/devtools/pull/2498)
* Run pub upgrade and update VMService wrapper. [#2496](https://github.com/flutter/devtools/pull/2496)
* Restore socket profiling state after hot restart [#2481](https://github.com/flutter/devtools/pull/248)
* Add vm service connection info and option to connect to a new app [#2484](https://github.com/flutter/devtools/pull/2484)
* Add selection styling to Logs table [#2485](https://github.com/flutter/devtools/pull/2485)
* Add support for hide=debugger [#2487](https://github.com/flutter/devtools/pull/2487)
* Don't reuse embedded windows in launchDevTools [#2489](https://github.com/flutter/devtools/pull/2489)

## 0.9.4
* Fix NPE in VM flags table [#2472](https://github.com/flutter/devtools/pull/2472)
* Color failed network requests with red status codes [#2466](https://github.com/flutter/devtools/pull/2466)
* Fix bug with Expand All control in the CPU profiler [#2465](https://github.com/flutter/devtools/pull/2465)
* Add average FPS information to the Timeline [#2462](https://github.com/flutter/devtools/pull/2462)
* Increase number of try ports when launching DevTools [#2458](https://github.com/flutter/devtools/pull/2458)
* Prevent dart.io extensions from being called on paused isolates [#2450](https://github.com/flutter/devtools/pull/2450)
* Remove the max zoom level bound for flame charts [#2447](https://github.com/flutter/devtools/pull/2447)
* Fix an NPE in the memory page [#2443](https://github.com/flutter/devtools/pull/2443)
* Add prompt for Q4 DevTools survey [#2442](https://github.com/flutter/devtools/pull/2442)
* Improvements to the memory page controls [#2432](https://github.com/flutter/devtools/pull/2432)
* Usability improvements for the Timeline Flutter frames chart [#2419](https://github.com/flutter/devtools/pull/2419), [#2421](https://github.com/flutter/devtools/pull/2421)
* Use new routing API to support permalinks [#2406](https://github.com/flutter/devtools/pull/2406)

## 0.9.3+4
* Do not try to launch Chrome by default when running the server in `--machine` mode
* Prevent exceptions launching Chrome from terminate the server

## 0.9.3+3
* Remove flutter dependency from devtools_shared

## 0.9.3+2
* Fix a bug causing "null" statuses in the Network profiler

## 0.9.3+1
* Added meta dependency to devtools_shared
* Group GC events together in the timeline
* Restore http logging state after hot restart
* Cleanup for DevTools dialogs

## 0.9.3
* Add search to the Network profiler [#2333](https://github.com/flutter/devtools/pull/2333)
* Add filtering to the Network profiler [#2340](https://github.com/flutter/devtools/pull/2340)
* Fix timeline rendering issue for async instant events [#2342](https://github.com/flutter/devtools/pull/2342)
* Display call graph and dominator tree for diffs in app size tool [#2344](https://github.com/flutter/devtools/pull/2344)
* Fix NPE in banner messages [#2358](https://github.com/flutter/devtools/pull/2358)
* Add "Dart DevTools" window title to web app [#2359](https://github.com/flutter/devtools/pull/2359)
* Rename "code size tool" to "app size tool" [#2365](https://github.com/flutter/devtools/pull/2365)
* Add search to Performance page CPU profiler [#2368](https://github.com/flutter/devtools/pull/2368)
* Fix analytics bug giving the incorrect value for "first run" [#2369](https://github.com/flutter/devtools/pull/2369)
* Collect RasterCache estimates from the Flutter engine in the Memory profiler [#2371](https://github.com/flutter/devtools/pull/2371)
* Display HTTP and HTTPS response bodies in the Network profiler [#2374](https://github.com/flutter/devtools/pull/2374)
* Pause should still record memory stats just not update charts [#2382](https://github.com/flutter/devtools/pull/2382)
* Simplify the debugger's libraries view [#2386](https://github.com/flutter/devtools/pull/2386)
* Make inspector polyfill compatible with both null safe and legacy Flutter [#2387](https://github.com/flutter/devtools/pull/2387)
* Fixed RSS plotting and plotting RasterCache data [#2389](https://github.com/flutter/devtools/pull/2389)

## 0.9.2
* Fix a bug causing extra evaluation for primitive values
* Fix an issue handling google3: paths [#2288](https://github.com/flutter/devtools/pull/2288)
* Update dependencies to use package:vm_service 5.0.0+1

## 0.9.1
* Add opt-in for feature usage reporting
* Add Code Size Debugging Tools to DevTools
* Use MIME types for http requests in the Network profiler

## 0.9.0
* Add search functionality to Timeline flame chart [#2164](https://github.com/flutter/devtools/pull/2164)
* Add socket profiling to Network page [#2191](https://github.com/flutter/devtools/pull/2191)
* Support multiple memory snapshots and support automatic snapshots [#2105](https://github.com/flutter/devtools/pull/2105)
* Add memory events pane and support for tracking # allocations of each class without a full snapshot [#2166](https://github.com/flutter/devtools/pull/2166)
* Replace heatmap with treemap on the memory page [#2131](https://github.com/flutter/devtools/pull/2131)
* Have the cmd-p keybinding toggle the libraries debugger pane [#2187](https://github.com/flutter/devtools/pull/2187)
* Add support for non-primitive map keys [#2154](https://github.com/flutter/devtools/pull/2154)
* Add tooltips to list items in the Debugger Libraries pane [#2167](https://github.com/flutter/devtools/pull/2167)

## 0.8.0+1
* Build with fix for canvas kit crasher

## 0.8.0
* Ship Flutter Web version of DevTools by default
* Update package:vm_service dependency to ^4.1.0

## 0.2.5
* Persist connected app URI when switching to Flutter web version of DevTools [#1933](https://github.com/flutter/devtools/pull/1933)
* Fix CPU profiler bug where we were unintentionally mutating data [#1923](https://github.com/flutter/devtools/pull/1923)
* Add "Remove all breakpoints" functionality to debugger [#1914](https://github.com/flutter/devtools/pull/1914)

## 0.2.4+1
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

## 0.2.3
* Disable Q1 DevTools survey - postponing until Q2 [#1695](https://github.com/flutter/devtools/pull/1695)
* Fix async timeline event rendering bug [#1690](https://github.com/flutter/devtools/pull/1690)
* Update package:vm_service dependency to ^3.0.0 [#1696](https://github.com/flutter/devtools/pull/1696)

## 0.2.2
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

## 0.1.15
* Fix a stack overflow error that was caused by a change in Dart's RTI implementation [#1615](https://github.com/flutter/devtools/pull/1615).
* Hide annotations that Flutter re-exports [#1606](https://github.com/flutter/devtools/pull/1606)
* Update package:devtools_server dependency to 0.1.13 or newer [#1603](https://github.com/flutter/devtools/pull/1603)
* Update package:sse dependency to 3.1.2 or newer [#1601](https://github.com/flutter/devtools/pull/1601)

## 0.1.14
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

## 0.1.13
* Fix crash opening macOS desktop apps in DevTools.
* Enable layout explorer.
* Hide legacy page content in the flutter version of DevTools.
* Fix offline import bug in Timeline.
* Use published version of mp_chart package.

## 0.1.12
* Enable testing the alpha version of DevTools written in Flutter. Click the "beaker" icon in the upper-right to launch DevTools in Flutter.
* Fix a regression that showed an inaccurate error on the connect screen.
* Fix bug causing async events with the same name to overlap each other in the Timeline.
* Include previously omitted args in Timeline event summary.
* Include "connected events" in the Timeline event summary, which are created via the dart:developer TimelineTask api.
* Reset debugger search bar on hot reload.
* Check for a debug service extension instead of using eval to distinguish between debug and profile builds.
* Depend on the latest `package:sse`.

## 0.1.11
* Add full timeline mode with support for async and recorded tracing.
* Add event summary section that shows metadata for non-ui events on the Timeline page.
* Enable full timeline for Dart CLI applications.
* Fix a message manager bug.
* Fix a bug with processing CPU profile responses.
* Reduce race conditions in integration tests.

## 0.1.10
* Change wording of DevTools survey prompt.

## 0.1.9
* Launched the Q3 DevTools Survey.
* Bug fixes related to layouts and logging.
* Update to use latest devtools_server 0.1.12.
* Remove usage of browser LocalStorage, previously used to store the user's answer to collect or not collect Analytics.
* Analytic's properties (firstRun, enabled) are now stored in local file ~/.devtools controlled by the devtools_server.
* Now devtools_app will request and set property values, in ~/.devtools, via HTTP requests to the devtools_server.
* Store survey properties on whether the user has answered or dismissed a survey in the ~/.devtools file too.

## 0.1.8
* Query a flutter isolate for the target frame rate (e.g. 60FPS vs 120FPS). Respect this value in the Timeline.
* Polish import / export flow for Timeline.
* Depend on latest `package:devtools_server`.

## 0.1.7
* Fix bug with profile mode detection.
* Enable expand all / collapse to selected functionality in the inspector (available in Flutter versions 1.10.1 or later).
* Fix analytics bug for apps running in profile mode.
* Fix bug in memory experiment handling.
* Hide Dart VM flags when the connected app is not running on the Dart VM (web apps).
* Former "Settings" screen is now the "Info" screen - updated icon accordingly.
* Various CSS fixes.
* Code health improvements.

## 0.1.6
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

## 0.1.5
* Support expanding or collapsing all values in the Call Tree and Bottom Up views (parts of the CPU profiler).
* Support touchscreen scrolling and selection in flame charts.
* Display structured error messages in the Logging view when "show structured errors" is enabled.
* Search and filter dialogs are now case-insensitive.
* Link to Dart DevTools documentation from connect screen.
* Disable unsupported DevTools pages for Dart web apps.
* Debugger dark mode improvements.

## 0.1.4
* Add Performance page. This has a traditional CPU profiler for Dart applications.
* Add ability to specify the profile granularity for the CPU profiler.
* Bug fixes for DevTools tables, memory page, and cpu profiler.

## 0.1.3
* Link to new flutter.dev hosted DevTools documentation.
* Inspector UI improvements.

## 0.1.2
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

## 0.1.1
* Make timeline snapshot format compatible with trace viewers such as chrome://tracing.
* Add ability to import timeline snapshots via drag-and-drop.
* Memory instance viewer handles all InstanceKind lists.
* CPU profiler bug fixes and improvements.

## 0.1.0
* Expose functionality to export timeline trace and CPU profiles.
* Add "Clear" button to the timeline page.
* CPU profiler bug fixes and improvements.
* Inspector polish bug fixes. Handle very deep inspector trees and only show expand-collapse arrows on tree nodes where needed.
* Fix case where error messages remained on the startup screen after the error had been fixed.
* Add ability to inspect an instance of a memory object in the memory profiler page after a snapshot of active memory objects.
* First time DevTools is launched, prompt with an opt-in dialog to report DevTools usage statistics and crash reports of DevTools to Google.

## 0.0.19
* Update DevTools server to better handle failures when launching browsers.
* Support additional formats for VM service uris.
* Link to documentation from --track-widget-creation warning in the Inspector.

## 0.0.18
* Fix release bug (0.0.17-dev.1 did not include build folder).
* Add CPU profiler (preview) to timeline page.
* CPU flame chart UI improvements and bug fixes.
* Bug fixes for DevTools on Windows.
* DevTools server released with support for launching DevTools in Chrome.
* Dark mode improvements.

## 0.0.16
* Reduce the minimum Dart SDK requirements for activating DevTools to cover Flutter v1.2.1 (Dart v2.1)

## 0.0.15
* Warn users when they should be using a profile build of their application instead of a debug build.
* Warn users using Microsoft browsers (IE and Edge) that they should be using Chrome to run DevTools.
* Dark mode improvements.
* Open scripts in the debugger using ctrl + o.

## 0.0.14
* Dark mode is ready to use, add ```&theme=dark``` at the end of the URI used to open the DevTool in Chrome. We look forward to your feedback.
* Added event timeline to memory profiler to track DevTool's Snapshot and Reset events.
* Timeline CPU renamed to UI, janky defined as UI duration + GPU duration > 16 ms.
* Timeline frame chart removed 8 ms highwater line, only 16 ms highwater line, display 2 traces ui/gpu (instead of 4). Janky frames will have a red glow.
* Flame chart colors use a different set of palettes and timeline is sticky.
* Warn users when they are using an unsupported browser.
* Properly disable features that aren't supported for the connected application.
* Fix screens for different widths.

## 0.0.13
* Dark mode, still being polished, is available.  Add ```&theme=dark``` at the end of URI used to open DevTools in the Chrome browser.
* Added showing GCs on the timeline and leak detection.
* Fix bugs when events were received out of order.

## 0.0.1
- initial (pre-release) release
