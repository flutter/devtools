## 2.18.0
* Add token permissions to allow signing scorecard results [#4555](https://github.com/flutter/devtools/pull/4555)
* Upgrade tests deps in refresh [#4529](https://github.com/flutter/devtools/pull/4529)
* Update "Allocations" memory JSON format to v2 [#4552](https://github.com/flutter/devtools/pull/4552)
* Remove more dead code from old allocations tab [#4546](https://github.com/flutter/devtools/pull/4546)
* Add multi-isolate support for `Allocation Tracing` tab [#4538](https://github.com/flutter/devtools/pull/4538)
* Add `Clear` button to `Allocation Tracing` tab [#4534](https://github.com/flutter/devtools/pull/4534)
* Update allocation profile column names [#4545](https://github.com/flutter/devtools/pull/4545)
* Bump ossf/scorecard-action from 2.0.0 to 2.0.4 [#4543](https://github.com/flutter/devtools/pull/4543)
* Provide `VMDeveloperToolsController` with `createController` [#4542](https://github.com/flutter/devtools/pull/4542)
* Show/hide chart on memory page and UX cleanups for control pane [#4520](https://github.com/flutter/devtools/pull/4520)
* Add test cases for file opener and file search visibility [#4531](https://github.com/flutter/devtools/pull/4531)
* Prepare dev release for g3 roll [#4530](https://github.com/flutter/devtools/pull/4530)
* Fix sorting column not being correctly updated in `AllocationProfileTableView` [#4532](https://github.com/flutter/devtools/pull/4532)
* Fix start-paused issue with inspector tab [#4527](https://github.com/flutter/devtools/pull/4527)
* Add support for inspecting objects in an isolate's object store [#4513](https://github.com/flutter/devtools/pull/4513)
* Enable new "Profile" and "Allocation Tracing" sub-tabs in Memory screen [#4523](https://github.com/flutter/devtools/pull/4523)
* Fixes broken file opener and search [#4525](https://github.com/flutter/devtools/pull/4525)
* Enable `Objects` tab and cleanup `VM Tools` screens [#4514](https://github.com/flutter/devtools/pull/4514)
* Show retaining paths for the class instances [#4515](https://github.com/flutter/devtools/pull/4515)
* Copyright fixes [#4518](https://github.com/flutter/devtools/pull/4518)
* Bump github/codeql-action from 2.1.24 to 2.1.25 [#4510](https://github.com/flutter/devtools/pull/4510)
* Fix banner messages to use ListValueNotifier [#4506](https://github.com/flutter/devtools/pull/4506)
* Fix for HoverCard Behaviour [#4488](https://github.com/flutter/devtools/pull/4488)
* Small reorg for heap related code [#4512](https://github.com/flutter/devtools/pull/4512)
* Diff heap statistics [#4501](https://github.com/flutter/devtools/pull/4501)
* Simplify frames chart to use a single ListView instead of multiple ListViews [#4503](https://github.com/flutter/devtools/pull/4503)
* Save last VM Service URI on landing screen in debug mode only [#4504](https://github.com/flutter/devtools/pull/4504)
* Fix exception in flame chart when widget became unmounted before callback completed [#4505](https://github.com/flutter/devtools/pull/4505)
* Fix crasher bug filtering empty frames [#4502](https://github.com/flutter/devtools/pull/4502)
* Refactor heap related code to prepare for diffing functionality [#4496](https://github.com/flutter/devtools/pull/4496)
* First chunk on snapshots visualization [#4473](https://github.com/flutter/devtools/pull/4473)
* Add offline support for the Raster stats data in the performance page [#4491](https://github.com/flutter/devtools/pull/4491)
* Update feature_flags.dart [#4485](https://github.com/flutter/devtools/pull/4485)
* Bump github/codeql-action from 2.1.23 to 2.1.24 [#4489](https://github.com/flutter/devtools/pull/4489)
* Add "Code Preview" section to Object Inspector views [#4447](https://github.com/flutter/devtools/pull/4447)
* Migrate away from deprecated text themes [#4486](https://github.com/flutter/devtools/pull/4486)
* Stop hiding log messages from non-stdout sources [#4487](https://github.com/flutter/devtools/pull/4487)
* Move feature flags to one location [#4483](https://github.com/flutter/devtools/pull/4483)
* Increase size of frame width in Flutter frames chart [#4480](https://github.com/flutter/devtools/pull/4480)
* Fixes for https://github.com/flutter/devtools/pull/4475 [#4478](https://github.com/flutter/devtools/pull/4478)
* Bump github/codeql-action from 2.1.19 to 2.1.23 [#4477](https://github.com/flutter/devtools/pull/4477)
* Refactor diff tab code to prepare for more code coming [#4475](https://github.com/flutter/devtools/pull/4475)
* Fix inspector Auto Scroll [#4283](https://github.com/flutter/devtools/pull/4283)
* Add 'Rendering time' column to Raster Metrics tab [#4474](https://github.com/flutter/devtools/pull/4474)
* Use a broadcast stream controller for the enhance tracing button [#4471](https://github.com/flutter/devtools/pull/4471)
* Bump to latest flutter beta [#4469](https://github.com/flutter/devtools/pull/4469)
* Adopt stager for DevTools [#4463](https://github.com/flutter/devtools/pull/4463)
* Fixing accidental MD whitespace [#4459](https://github.com/flutter/devtools/pull/4459)
* Fix misc bugs in CPU profile trees [#4413](https://github.com/flutter/devtools/pull/4413)
* Search FileExplorer and Outline nodes [#4466](https://github.com/flutter/devtools/pull/4466)
* Add field for shallow size and move leak-related logic from the folder 'shared' to the folder 'leaks' [#4458](https://github.com/flutter/devtools/pull/4458)
* Upload golden image failures as artifacts [#4456](https://github.com/flutter/devtools/pull/4456)
* Reorganize file structure for memory screen [#4457](https://github.com/flutter/devtools/pull/4457)
* Manage Android chart via settings and other improvements [#4370](https://github.com/flutter/devtools/pull/4370)
* Fix `CodeView`'s scrollable area [#4448](https://github.com/flutter/devtools/pull/4448)
* Bump ossf/scorecard-action from 1.1.2 to 2.0.0 [#4454](https://github.com/flutter/devtools/pull/4454)
* Convert polyfill script to null safety [#4453](https://github.com/flutter/devtools/pull/4453)
* Update CONTRIBUTING.md [#4445](https://github.com/flutter/devtools/pull/4445)
* Create draft for release notes [#4440](https://github.com/flutter/devtools/pull/4440)
* Fix casting issues with Raster Metrics Tab [#4444](https://github.com/flutter/devtools/pull/4444)
* Update README.md [#4443](https://github.com/flutter/devtools/pull/4443)
* Fix Network recordings after hot restart [#4438](https://github.com/flutter/devtools/pull/4438)
* Fix inspector exception when app paused [#4418](https://github.com/flutter/devtools/pull/4418)
* Update release instruction [#4432](https://github.com/flutter/devtools/pull/4432)
* Update to latest textmate grammar and support nested captures in parser [#4427](https://github.com/flutter/devtools/pull/4427)
* Require args v2.1.0 in tool because code uses "mandatory" parameter [#4435](https://github.com/flutter/devtools/pull/4435)
* Polish UI for VmExpansionTile [#4436](https://github.com/flutter/devtools/pull/4436)
* Improve testing of `ProgramExplorer` [#4424](https://github.com/flutter/devtools/pull/4424)
* Update memory goldens [#4437](https://github.com/flutter/devtools/pull/4437)
* Add support for a `Call Tree` view in the `Allocation Tracing` pane [#4403](https://github.com/flutter/devtools/pull/4403)
* CPU Profiler tab UI cleanup [#4404](https://github.com/flutter/devtools/pull/4404)
* Persist sorting order for Memory Profile table [#4405](https://github.com/flutter/devtools/pull/4405)
* Migrate case studies to null safety [#4420](https://github.com/flutter/devtools/pull/4420)
* Update README.md [#4426](https://github.com/flutter/devtools/pull/4426)
* Add minor changes to README.md [#4431](https://github.com/flutter/devtools/pull/4431)

## 2.17.0
* Prepare for 2.17.0 release [#4428](https://github.com/flutter/devtools/pull/4428)
* Revert perfetto bundle [#4422](https://github.com/flutter/devtools/pull/4422)
* Handle nested scopes better when parsing code for syntax highlighting [#4363](https://github.com/flutter/devtools/pull/4363)
* Make fixes for internal checks [#4415](https://github.com/flutter/devtools/pull/4415)
* Bump version to 2.16.0-dev.0 [#4414](https://github.com/flutter/devtools/pull/4414)
* Upgrade to latest Flutter beta [#4410](https://github.com/flutter/devtools/pull/4410)
* Update helper for bumping versions [#4406](https://github.com/flutter/devtools/pull/4406)
* VM Developer Tools screen IndexedStack & other changes [#4382](https://github.com/flutter/devtools/pull/4382)
* Add support for pinning items to `FlatTable` [#4383](https://github.com/flutter/devtools/pull/4383)
* Add unsafe_html lint to DevTools [#4396](https://github.com/flutter/devtools/pull/4396)
* Bundle the perfetto build in assets/ along with the DevTools custom theme [#4395](https://github.com/flutter/devtools/pull/4395)
* Comment out _updateLocalClasses code [#4394](https://github.com/flutter/devtools/pull/4394)
* Add functionality to load timeline trace in the perfetto ui [#4392](https://github.com/flutter/devtools/pull/4392)
* Add filtering support to Allocation Tracing tab [#4377](https://github.com/flutter/devtools/pull/4377)
* Bump github/codeql-action from 2.1.18 to 2.1.19 [#4389](https://github.com/flutter/devtools/pull/4389)
* Update actions/upload-artifact requirement to 3cea5372237819ed00197afe530f5a7ea3e805c8 [#4390](https://github.com/flutter/devtools/pull/4390)
* Bump actions/checkout from 2 to 3.0.2 [#4391](https://github.com/flutter/devtools/pull/4391)
* Add skeleton for embedded perfetto trace viewer [#4386](https://github.com/flutter/devtools/pull/4386)
* Keep in line with g3's needs [#4384](https://github.com/flutter/devtools/pull/4384)
* Upgrade to latest flutter beta [#4385](https://github.com/flutter/devtools/pull/4385)
* Fix Eager Inspector Refresh [#4378](https://github.com/flutter/devtools/pull/4378)
* Update desktop storage file to use the same file as production devtools [#4379](https://github.com/flutter/devtools/pull/4379)
* Library display initial implementation [#4350](https://github.com/flutter/devtools/pull/4350)
* InspectorService may not always be present [#4374](https://github.com/flutter/devtools/pull/4374)
* Fix getPubRootDirectories so it works over Dart Debug Extension [#4372](https://github.com/flutter/devtools/pull/4372)
* Initial implementation of `Tracing` tab [#4364](https://github.com/flutter/devtools/pull/4364)
* Script display initial implementation [#4349](https://github.com/flutter/devtools/pull/4349)
* Change ValueNotifier to ValueListenable [#4366](https://github.com/flutter/devtools/pull/4366)
* VmFuncDisplay Initial implementation [#4323](https://github.com/flutter/devtools/pull/4323)
* Add some notes about configuring VS Code to run DevTools from local code [#4356](https://github.com/flutter/devtools/pull/4356)
* Adding drop down to diff table [#4354](https://github.com/flutter/devtools/pull/4354)
* `fileNameFromUri` utility method [#4359](https://github.com/flutter/devtools/pull/4359)
* Fix ordering of spans in syntax highlighting goldens [#4362](https://github.com/flutter/devtools/pull/4362)
* Add InspectorController to list of generated mocks [#4358](https://github.com/flutter/devtools/pull/4358)
* Fix syntax highlighting for endCaptures [#4361](https://github.com/flutter/devtools/pull/4361)
* Add a client API method to allow the server to ping a client to see if it's still responsive [#4355](https://github.com/flutter/devtools/pull/4355)
* Fix off-by-one error in syntax highlighting goldens + truncate to not include newlines [#4333](https://github.com/flutter/devtools/pull/4333)
* Fix typos [#4351](https://github.com/flutter/devtools/pull/4351)
* Refactor notifications and chart pane [#4263](https://github.com/flutter/devtools/pull/4263)
* Adding multi-package support for pubrootdirectories [#4306](https://github.com/flutter/devtools/pull/4306)
* Refactor RequestableSizeWidget [#4340](https://github.com/flutter/devtools/pull/4340)
* Use G3 compatible icons [#4347](https://github.com/flutter/devtools/pull/4347)
* App Size panel clean-up [#4346](https://github.com/flutter/devtools/pull/4346)
* Adding ArtificialRoot to non-deferred apps for diff table [#4338](https://github.com/flutter/devtools/pull/4338)
* Expand and Unexpand top nodes in Treetable [#4313](https://github.com/flutter/devtools/pull/4313)
* Update release_notes README.md [#4345](https://github.com/flutter/devtools/pull/4345)
* Update broken link on release instructions [#4344](https://github.com/flutter/devtools/pull/4344)
* Field Display initial implementation [#4322](https://github.com/flutter/devtools/pull/4322)
* Bump github/codeql-action from 2.1.17 to 2.1.18 [#4341](https://github.com/flutter/devtools/pull/4341)
* Turn on Frame Analysis feature by default and add more analytics [#4339](https://github.com/flutter/devtools/pull/4339)
* Move framework-only code to the folder 'framework' [#4334](https://github.com/flutter/devtools/pull/4334)
* Write tests for frame hints [#4337](https://github.com/flutter/devtools/pull/4337)
* Migrate ClipboardStatusNotifier [#4122](https://github.com/flutter/devtools/pull/4122)
* Add a dropdown to App Size analysis tab [#4332](https://github.com/flutter/devtools/pull/4332)
* Forward args from devtools build_e2e.dart to pkg:dds/serve_local.dart [#4331](https://github.com/flutter/devtools/pull/4331)
* Add key and value types to VmInfoCard mapEntries [#4329](https://github.com/flutter/devtools/pull/4329)
* Extract some span_parser tests into "golden" tests [#4325](https://github.com/flutter/devtools/pull/4325)
* Rewrite FrameTimeVisualizer in performance page [#4328](https://github.com/flutter/devtools/pull/4328)
* Fix layoutPhase calculation [#4327](https://github.com/flutter/devtools/pull/4327)
* Add information about performance impact [#4324](https://github.com/flutter/devtools/pull/4324)
* Adding deferred indicator on the treetable [#4305](https://github.com/flutter/devtools/pull/4305)
* Update LEAK_TRACKING.md [#4273](https://github.com/flutter/devtools/pull/4273)
* Update release instructions [#4320](https://github.com/flutter/devtools/pull/4320)
* Bump to latest flutter beta [#4319](https://github.com/flutter/devtools/pull/4319)
* Minor changes for leak tracking doc [#4318](https://github.com/flutter/devtools/pull/4318)
* Bump github/codeql-action from 2.1.15 to 2.1.17 [#4317](https://github.com/flutter/devtools/pull/4317)
* Add MacOS bot to the CI [#4078](https://github.com/flutter/devtools/pull/4078)
* Improve helper functions in vm_developer_common_widgets [#4312](https://github.com/flutter/devtools/pull/4312)

## 2.16.0
* Prepare for 2.16.0 release [#4311](https://github.com/flutter/devtools/pull/4311)
* Fix shader time calculation with `shallowNodesWithCondition` TreeNode method [#4309](https://github.com/flutter/devtools/pull/4309)
* Fix bug with msText util [#4310](https://github.com/flutter/devtools/pull/4310)
* Remove dependency on memory_controller from allocation profile pane [#4301](https://github.com/flutter/devtools/pull/4301)
* Adding deferred indicator on the treemap [#4297](https://github.com/flutter/devtools/pull/4297)
* Class display [#4256](https://github.com/flutter/devtools/pull/4256)
* Initial implementation of `VmCodeDisplay` in program explorer [#4280](https://github.com/flutter/devtools/pull/4280)
* Make tabs on memory screen looking nicer [#4291](https://github.com/flutter/devtools/pull/4291)
* Add steps to detect memory leaks for dart app [#4292](https://github.com/flutter/devtools/pull/4292)
* Improve `msText` util to support preventing zero values [#4298](https://github.com/flutter/devtools/pull/4298)
* Remove deprecated experimental invariant_booleans lint rule [#4294](https://github.com/flutter/devtools/pull/4294)
* Deferred nodes are gray scaled on TreeMap [#4296](https://github.com/flutter/devtools/pull/4296)
* TreeMap opens directly to main root for deferred apps [#4286](https://github.com/flutter/devtools/pull/4286)
* Refactor performance code for better organization [#4293](https://github.com/flutter/devtools/pull/4293)
* Make UI jank hints aware of the enhance tracing state for a frame [#4288](https://github.com/flutter/devtools/pull/4288)
* Package Directory Interface [#4251](https://github.com/flutter/devtools/pull/4251)
* Deferred Info UI TreeTable Update [#4278](https://github.com/flutter/devtools/pull/4278)
* Add EnhanceTracingController and show enhance tracing dialog from button in hint [#4281](https://github.com/flutter/devtools/pull/4281)
* Cleanup some theming for IconLabelButton [#4282](https://github.com/flutter/devtools/pull/4282)
* Update project.pbxproj [#4277](https://github.com/flutter/devtools/pull/4277)
* Initial implementation of `AllocationProfileTableView` [#4257](https://github.com/flutter/devtools/pull/4257)
* Support parsing the following ANSI styles [#4271](https://github.com/flutter/devtools/pull/4271)
* Fix regression where value of `ColumnData.supportsSorting` was not respected [#4275](https://github.com/flutter/devtools/pull/4275)
* Adding feature flag for deferred loading [#4272](https://github.com/flutter/devtools/pull/4272)
* Unskip inspector golden tests [#4269](https://github.com/flutter/devtools/pull/4269)
* Connect the TreeTable and TreeMap [#4226](https://github.com/flutter/devtools/pull/4226)
* Bump pinned flutter version to latest beta [#4268](https://github.com/flutter/devtools/pull/4268)
* Ran `dart fix` to resolve new analysis warnings introduced by `package:vm_service` [#4267](https://github.com/flutter/devtools/pull/4267)
* Show/edit list of snapshots [#4260](https://github.com/flutter/devtools/pull/4260)
* Add hints for expensive operations to the Frame Analysis view [#4261](https://github.com/flutter/devtools/pull/4261)
* Address UX review comments [#4262](https://github.com/flutter/devtools/pull/4262)
* Debugger bugs [#4248](https://github.com/flutter/devtools/pull/4248)
* Add analytics to all documentation links [#4259](https://github.com/flutter/devtools/pull/4259)
* Clean up TODO to remove iOS profiling workaround message [#4258](https://github.com/flutter/devtools/pull/4258)
* Create scaffold for memory diff pane [#4255](https://github.com/flutter/devtools/pull/4255)
* Move utility method to primitives [#4254](https://github.com/flutter/devtools/pull/4254)
* Fix accidental double-padding around GroupColumnSpacer [#4253](https://github.com/flutter/devtools/pull/4253)
* Provide the InspectorController through package:provider [#4244](https://github.com/flutter/devtools/pull/4244)
* Increase timeout on failing eval_integration_test [#4252](https://github.com/flutter/devtools/pull/4252)
* Create MemoryChartPaneController [#4243](https://github.com/flutter/devtools/pull/4243)
* Change formatting for file name to make it sortable by time and the time recognizable by human [#4242](https://github.com/flutter/devtools/pull/4242)
* Exclude WeakProperty from retaining path and validate library [#4247](https://github.com/flutter/devtools/pull/4247)
* Minor improvements for leak tracker [#4246](https://github.com/flutter/devtools/pull/4246)
* Analyze and report leaks. [#4236](https://github.com/flutter/devtools/pull/4236)
* Update leak tracking doc [#4240](https://github.com/flutter/devtools/pull/4240)
* Remove unused var from CpuProfileFlameChart [#4239](https://github.com/flutter/devtools/pull/4239)
* Update LEAK_TRACKING.md [#4235](https://github.com/flutter/devtools/pull/4235)
* Receive leak summary reports [#4223](https://github.com/flutter/devtools/pull/4223)

## 2.15.0
* Add VM object inspector [#4195](https://github.com/flutter/devtools/pull/4195)
* Added edge case when popping history on a one-item stack [#4230](https://github.com/flutter/devtools/pull/4230)
* Bump github/codeql-action from 2.1.14 to 2.1.15 [#4229](https://github.com/flutter/devtools/pull/4229)
* Fixes 2 bugs that were happening in the VM tools tabs [#4215](https://github.com/flutter/devtools/pull/4215)
* Restored all other files and edited codeview.dart [#4187](https://github.com/flutter/devtools/pull/4187)
* Fix Scrollbar error with ProgramExplorer [#4228](https://github.com/flutter/devtools/pull/4228)
* Add custom dimension for g3 username [#4221](https://github.com/flutter/devtools/pull/4221)
* Update Scorecard-actions to address workflow failure [#4219](https://github.com/flutter/devtools/pull/4219)
* Remove Flutter environment dependency from Performance Controller tests [#4216](https://github.com/flutter/devtools/pull/4216)
* Add support for column groups in tables [#4214](https://github.com/flutter/devtools/pull/4214)
* Bump github/codeql-action from 2.1.12 to 2.1.14 [#4212](https://github.com/flutter/devtools/pull/4212)
* Create tab 'Leaks' [#4211](https://github.com/flutter/devtools/pull/4211)
* Separate memory chart related code to a dedicated folder [#4199](https://github.com/flutter/devtools/pull/4199)
* Make auto-snapshotting configurable - [#4200](https://github.com/flutter/devtools/pull/4200)
* Some renamings in preferences [#4198](https://github.com/flutter/devtools/pull/4198)
* Copy Network Response [#4190](https://github.com/flutter/devtools/pull/4190)
* Comment out Flaky dependency tests for now [#4204](https://github.com/flutter/devtools/pull/4204)
* Bump flutter version to latest beta [#4194](https://github.com/flutter/devtools/pull/4194)
* Add layer outlines to the raster metrics tab in the performance view [#4192](https://github.com/flutter/devtools/pull/4192)
* Set displayRefreshRate from offline performance data imports [#4189](https://github.com/flutter/devtools/pull/4189)
* Fix a couple of exceptions [#4186](https://github.com/flutter/devtools/pull/4186)
* Enable sort_child_properties_last lint [#4124](https://github.com/flutter/devtools/pull/4124)
* Small Improvements to generate_code script [#4180](https://github.com/flutter/devtools/pull/4180)
* Removing Retry Logic [#4178](https://github.com/flutter/devtools/pull/4178)
* Migrate ThemeData.toggleableActiveColor [#4149](https://github.com/flutter/devtools/pull/4149)
* Fix Slow Event Log Scrolling for large # of events [#4175](https://github.com/flutter/devtools/pull/4175)
* Add isolate selection support to memory screen + other minor UI fixes [#4173](https://github.com/flutter/devtools/pull/4173)
* Add `JsonViewer` widget and update formatting / highlighting of `ExpandableVariable` [#4167](https://github.com/flutter/devtools/pull/4167)
* Fix method alignment and remove manual truncation of methods [#4166](https://github.com/flutter/devtools/pull/4166)
* Add a mixin for comparing enums by index [#4121](https://github.com/flutter/devtools/pull/4121)
* Add missing textSelectionColor for breakpoints and callstack [#4169](https://github.com/flutter/devtools/pull/4169)
* Move existing code into shared/utils for shared use in g3 [#4168](https://github.com/flutter/devtools/pull/4168)
* Bump github/codeql-action from 1.1.5 to 2.1.12 [#4165](https://github.com/flutter/devtools/pull/4165)
* Bump ossf/scorecard-action from 1.0.4 to 1.1.1 [#4164](https://github.com/flutter/devtools/pull/4164)
* Pin github actions to hash, add dependabot for actions as well [#4163](https://github.com/flutter/devtools/pull/4163)
* Fix typo in documentation [#4162](https://github.com/flutter/devtools/pull/4162)

## 2.14.1
* Bump version to 2.14.1 for devtools_shared release [#4208](https://github.com/flutter/devtools/pull/4208)
* Bump vm_service dep to 9.0.0 [#4161](https://github.com/flutter/devtools/pull/4161)

## 2.14.0
* Prepare for 2.14.0 release [#4157](https://github.com/flutter/devtools/pull/4157)
* Lookup frame id from 'Rasterizer::DoDraw' event [#4156](https://github.com/flutter/devtools/pull/4156)
* Fix formatting for memory values in heap tree view [#4153](https://github.com/flutter/devtools/pull/4153)
* Create `ProvidedControllerMixin` and use throughout DevTools [#4150](https://github.com/flutter/devtools/pull/4150)
* Add ability to copy file and package from debugger [#4147](https://github.com/flutter/devtools/pull/4147)
* Hover less [#4090](https://github.com/flutter/devtools/pull/4090)
* Test that debugging flags are never enabled in production [#4148](https://github.com/flutter/devtools/pull/4148)
* Move controls related code to a separate folder [#4136](https://github.com/flutter/devtools/pull/4136)
* Create PerformanceControllerMixin and use in performance components [#4146](https://github.com/flutter/devtools/pull/4146)
* Migrate primary of `CustomPointerScrollView` [#4117](https://github.com/flutter/devtools/pull/4117)
* Delete `memory_service.dart` [#4135](https://github.com/flutter/devtools/pull/4135)
* Fix late initialization error and remove dead code [#4134](https://github.com/flutter/devtools/pull/4134)
* Reduce area of concern for low level memory libraries and move some to `memory/primitives` [#4132](https://github.com/flutter/devtools/pull/4132)
* Update `memory_protocol.dart` [#4125](https://github.com/flutter/devtools/pull/4125)
* Recover blue dots (GC events) [#4131](https://github.com/flutter/devtools/pull/4131)
* Support connecting to apps ran with --no_dds [#4119](https://github.com/flutter/devtools/pull/4119)
* Fix typo in dart doc [#4120](https://github.com/flutter/devtools/pull/4120)
* Hide the Raster Metrics and Frame Analysis tabs for non flutter apps [#4118](https://github.com/flutter/devtools/pull/4118)
* Add devtools version and device info to github issue description [#4112](https://github.com/flutter/devtools/pull/4112)
* Add copy actions to network requests (Copy as URL, cURL) [#4113](https://github.com/flutter/devtools/pull/4113)
* Move `service_extension_widgets.dart` to `service/` dir [#4106](https://github.com/flutter/devtools/pull/4106)
* Fix casting errors on memory screen [#4104](https://github.com/flutter/devtools/pull/4104)
* Add discord channel link to DevTools about dialog [#4102](https://github.com/flutter/devtools/pull/4102)
* Upgrade package:flutter_riverpod dependency to eliminate null-safety warnings [#4089](https://github.com/flutter/devtools/pull/4089)
* Use AutomaticKeepAlive on the FlameChart widget [#4088](https://github.com/flutter/devtools/pull/4088)
* Reduce chart heights and size of flutter frame bars [#4087](https://github.com/flutter/devtools/pull/4087)
* Null safe memory case study [#4054](https://github.com/flutter/devtools/pull/4054)
* Add new optional `libraryFilters` parameter to VM service getSourceReport [#4086](https://github.com/flutter/devtools/pull/4086)
* Fix formatting in debugger exception menu [#4066](https://github.com/flutter/devtools/pull/4066)
* "More debug options" warning when in profile mode [#4075](https://github.com/flutter/devtools/pull/4075)
* Add auto complete suggestions in eval text field [#4062](https://github.com/flutter/devtools/pull/4062)

## 2.13.1
* Prepare for 2.13.1 release [#4079](https://github.com/flutter/devtools/pull/4079)
* Add "publish_to: none" to devtools_app and devtools_test pubspecs [#4077](https://github.com/flutter/devtools/pull/4077)
* Polish connection status [#4076](https://github.com/flutter/devtools/pull/4076)
* Fix breakpoint scrolling bug [#4074](https://github.com/flutter/devtools/pull/4074)
* Display flex values larger than 5 [#4055](https://github.com/flutter/devtools/pull/4055)
* Upgrade package:provider version to eliminate null safety warnings [#4065](https://github.com/flutter/devtools/pull/4065)

## 2.13.0
* Release notes in small screens [#4053](https://github.com/flutter/devtools/pull/4053)
* Bump pinned flutter version to latest Flutter Beta [#4063](https://github.com/flutter/devtools/pull/4063)
* Refactor tests into subdirectories [#4057](https://github.com/flutter/devtools/pull/4057)
* Include the footer when DevTools is embedded [#4041](https://github.com/flutter/devtools/pull/4041)
* Enable raster metrics feature by default [#4056](https://github.com/flutter/devtools/pull/4056)
* Fix nullability errors in the provider screen [#4059](https://github.com/flutter/devtools/pull/4059)
* Only check goldens on bots that run against the pinned flutter version [#4061](https://github.com/flutter/devtools/pull/4061)
* Refactor performance code [#4047](https://github.com/flutter/devtools/pull/4047)
* Update linux configuration [#4052](https://github.com/flutter/devtools/pull/4052)
* Remove the flag --no-sound-null-safety from test run [#4045](https://github.com/flutter/devtools/pull/4045)
* Test cleanup [#4048](https://github.com/flutter/devtools/pull/4048)
* Migrate some tests from unsound to sound null safety (6) [#4044](https://github.com/flutter/devtools/pull/4044)
* Add raster metrics visualizer to performance page [#4046](https://github.com/flutter/devtools/pull/4046)
* Migrate some tests from unsound to sound null safety (4) [#4036](https://github.com/flutter/devtools/pull/4036)
* Switch to using Path URL Strategy [#3585](https://github.com/flutter/devtools/pull/3585)
* Migrate some tests from unsound to sound null safety [#4034](https://github.com/flutter/devtools/pull/4034)
* Fix url_launcher dependency version [#4043](https://github.com/flutter/devtools/pull/4043)
* Remove frame analysis icon from flutter frames chart [#4032](https://github.com/flutter/devtools/pull/4032)
* Fix debugger_floating_test and others [#4030](https://github.com/flutter/devtools/pull/4030)
* Fix function signature alignment in file explorer [#4040](https://github.com/flutter/devtools/pull/4040)
* Split scaffold_test [#4035](https://github.com/flutter/devtools/pull/4035)
* Split debugger_screen_test [#4033](https://github.com/flutter/devtools/pull/4033)
* Fix logging_screen_test.dart [#4023](https://github.com/flutter/devtools/pull/4023)
* Fix spacing of items in the status line footer [#4026](https://github.com/flutter/devtools/pull/4026)
* Fix tooltip colouring for "select widget mode" [#4017](https://github.com/flutter/devtools/pull/4017)
* Split logging_screen_test [#4031](https://github.com/flutter/devtools/pull/4031)
* Add tabbed view to the performance page [#4025](https://github.com/flutter/devtools/pull/4025)
* Fix debugger_controller_test [#4020](https://github.com/flutter/devtools/pull/4020)
* Fix cpu_profiler_test and others [#4019](https://github.com/flutter/devtools/pull/4019)
* Split debugger_controller_test [#4021](https://github.com/flutter/devtools/pull/4021)
* Fix chart_test [#4018](https://github.com/flutter/devtools/pull/4018)
* Split debugger_screen_test.dart [#4015](https://github.com/flutter/devtools/pull/4015)
* Add execute permissions to refresh scripts [#4013](https://github.com/flutter/devtools/pull/4013)
* Ensure sourceLine is properly passed in all places [#4004](https://github.com/flutter/devtools/pull/4004)
* Address comments in https://github.com/flutter/devtools/pull/4009 [#4011](https://github.com/flutter/devtools/pull/4011)
* Remove unnecessary 'ignore...' [#4009](https://github.com/flutter/devtools/pull/4009)
* Add setting for tracking user-created widget builds [#4010](https://github.com/flutter/devtools/pull/4010)
* Migrate tests to null safety [#4006](https://github.com/flutter/devtools/pull/4006)
* Update file_import.dart [#4008](https://github.com/flutter/devtools/pull/4008)
* Update fake_isolate_manager.dart [#4005](https://github.com/flutter/devtools/pull/4005)
* Migrate mocks and tests to null safety [#3982](https://github.com/flutter/devtools/pull/3982)
* Update CONTRIBUTING.md [#4001](https://github.com/flutter/devtools/pull/4001)
* Clean up analytics for checkbox settings [#4000](https://github.com/flutter/devtools/pull/4000)
* Migrate some mocks to null safety [#3973](https://github.com/flutter/devtools/pull/3973)
* Isolate selector in footer bar is a `PopupMenu` instead of a `DropdownMenu` [#3989](https://github.com/flutter/devtools/pull/3989)
* Using lookupPackageUris for stack frame processedUrls [#3932](https://github.com/flutter/devtools/pull/3932)
* Fix the edit of private properties [#3990](https://github.com/flutter/devtools/pull/3990)
* Add a repository field to the pubspecs [#3992](https://github.com/flutter/devtools/pull/3992)
* Fix null safety errors across DevTools [#3983](https://github.com/flutter/devtools/pull/3983)
* Bump flutter-version to the latest beta [#3988](https://github.com/flutter/devtools/pull/3988)
* Update comment about since-tag in CHANGELOG generator [#3979](https://github.com/flutter/devtools/pull/3979)
* Prepare for `2.13.0-dev.1 release` [#3978](https://github.com/flutter/devtools/pull/3978)
* Update CONTRIBUTING.md [#3981](https://github.com/flutter/devtools/pull/3981)
* Move shared profiler code to profiler_utils.dart [#3977](https://github.com/flutter/devtools/pull/3977)
* Set same-site cookie for Google Analytics [#3975](https://github.com/flutter/devtools/pull/3975)
* Create ProfilableDataMixin and generalize bottom up transformer code [#3976](https://github.com/flutter/devtools/pull/3976)
* Migrate remaining in dev_tools lib to null safety [#3971](https://github.com/flutter/devtools/pull/3971)
* Migrate provider screen to null-safety [#3915](https://github.com/flutter/devtools/pull/3915)
* Move getCpuProfileTimeline from VmServiceWrapper to CpuProfileModel [#3946](https://github.com/flutter/devtools/pull/3946)
* Migrate the debugger panel to null-safety [#3927](https://github.com/flutter/devtools/pull/3927)
* Move dwds pageReady event in the inspector [#3963](https://github.com/flutter/devtools/pull/3963)
* Add enhance tracing hints to the frame analysis view [#3959](https://github.com/flutter/devtools/pull/3959)
* Removing gradle-wrapper.jar file [#3947](https://github.com/flutter/devtools/pull/3947)
* Add scorecards to devtools repo [#3900](https://github.com/flutter/devtools/pull/3900)
* Add lint to handle trailing comnmas [#3943](https://github.com/flutter/devtools/pull/3943)
* Handle more than 100 commits in the changelog generator [#3938](https://github.com/flutter/devtools/pull/3938)
* Change file explorer icon in to folder [#3944](https://github.com/flutter/devtools/pull/3944)
* Migrate inspector to null safety [#3928](https://github.com/flutter/devtools/pull/3928)

## 2.12.2
* Prep for 2.12.2 cherrypick release [#3961](https://github.com/flutter/devtools/pull/3961)
* Recover from missing trace events [#3960](https://github.com/flutter/devtools/pull/3960)
* Only send the dwds event when the service is registered [#3953](https://github.com/flutter/devtools/pull/3953)
* Add analytics to track inspector tree first load time [#3924](https://github.com/flutter/devtools/pull/3924)
* Update changelog for 2.12.2 [#3962](https://github.com/flutter/devtools/pull/3962)

## 2.12.1
* Fix null safety errors and prep for 2.12.1 release [#3939](https://github.com/flutter/devtools/pull/3939)

## 2.12.0
* Prep for 2.12.0 release [#3937](https://github.com/flutter/devtools/pull/3937)
* Add documentation links to More Debugging Options menu [#3936](https://github.com/flutter/devtools/pull/3936)
* Add documentation links to Enhance Tracing options [#3934](https://github.com/flutter/devtools/pull/3934)
* Add scrolling support to all hover cards [#3923](https://github.com/flutter/devtools/pull/3923)
* Migrate inspector ui to null safety [#3895](https://github.com/flutter/devtools/pull/3895)
* Refactor script caching logic out of `DebuggerController` into `ScriptManager` [#3914](https://github.com/flutter/devtools/pull/3914)
* Update bots.sh to fix build for web [#3913](https://github.com/flutter/devtools/pull/3913)
* Remove service protocol version checks in DevTools [#3907](https://github.com/flutter/devtools/pull/3907)
* Add flag --no-sound-null-safety to instructions and goldens [#3909](https://github.com/flutter/devtools/pull/3909)
* Add a ga hit when an inspector tree node is selected [#3906](https://github.com/flutter/devtools/pull/3906)
* Add additional variants of inspector goldens to prevent test flakes [#3905](https://github.com/flutter/devtools/pull/3905)
* Bump minimum dart sdk version to 2.15.0 [#3904](https://github.com/flutter/devtools/pull/3904)
* Update to the latest flutter beta [#3894](https://github.com/flutter/devtools/pull/3894)
* Fix null-safety related errors in tests [#3903](https://github.com/flutter/devtools/pull/3903)
* Migrate tests t-w to null safety [#3890](https://github.com/flutter/devtools/pull/3890)
* Migrate tests f-i to null safety [#3887](https://github.com/flutter/devtools/pull/3887)
* Migrate layout_explorer, matchers and provider tests to null safety [#3872](https://github.com/flutter/devtools/pull/3872)
* Migrate tests p-s to null safety [#3889](https://github.com/flutter/devtools/pull/3889)
* Migrate tests l-n to null safety [#3888](https://github.com/flutter/devtools/pull/3888)
* Migrate tests a-c to null safety [#3883](https://github.com/flutter/devtools/pull/3883)
* Migrate ansi_up_test to null safety [#3885](https://github.com/flutter/devtools/pull/3885)
* Migrate memory_screen to null safety [#3893](https://github.com/flutter/devtools/pull/3893)
* Migrate test data and infra to null safety [#3873](https://github.com/flutter/devtools/pull/3873)
* Fix noisy test logs on flutter driver tests [#3901](https://github.com/flutter/devtools/pull/3901)
* Service worker should not claim other clients on activate [#3899](https://github.com/flutter/devtools/pull/3899)
* Migrate diagnostics_node to null safety [#3892](https://github.com/flutter/devtools/pull/3892)
* Migrate test utils to null safety. [#3882](https://github.com/flutter/devtools/pull/3882)
* Migrate networking screen to null safety [#3880](https://github.com/flutter/devtools/pull/3880)
* Migrate memory_heap_tree_view.dart to null safety [#3881](https://github.com/flutter/devtools/pull/3881)
* Migrate breadcrumb to null safety [#3891](https://github.com/flutter/devtools/pull/3891)
* Migrate inspector_service to null safety [#3854](https://github.com/flutter/devtools/pull/3854)
* Migrate test fixtures to null safety [#3870](https://github.com/flutter/devtools/pull/3870)
* Migrate tests d-e to null safety [#3884](https://github.com/flutter/devtools/pull/3884)
* Update bots to run tests with --no-sound-null-safety [#3886](https://github.com/flutter/devtools/pull/3886)
* Send pageReady event to dwds from Inspector page [#3834](https://github.com/flutter/devtools/pull/3834)
* Migrate instance_viewer and integration tests to null safety [#3871](https://github.com/flutter/devtools/pull/3871)
* Migrate inspector ui primitives to null safety [#3855](https://github.com/flutter/devtools/pull/3855)
* Migrate memory_charts.dart to null safety [#3853](https://github.com/flutter/devtools/pull/3853)
* Migrate memory_instance_tree_view.dart to null safety [#3852](https://github.com/flutter/devtools/pull/3852)
* Migrate log screen to null safety [#3857](https://github.com/flutter/devtools/pull/3857)
* Migrate `app_size/` code to null safety [#3866](https://github.com/flutter/devtools/pull/3866)
* Migrate `performance/` code to null safety [#3848](https://github.com/flutter/devtools/pull/3848)
* Migrate _message_column.dart to null safety [#3851](https://github.com/flutter/devtools/pull/3851)
* Migrate _log_details.dart to null safety [#3838](https://github.com/flutter/devtools/pull/3838)
* Update table_data.dart [#3847](https://github.com/flutter/devtools/pull/3847)
* Fix casting errors [#3849](https://github.com/flutter/devtools/pull/3849)
* Migrate memory_heap_treemap.dart to null safety [#3840](https://github.com/flutter/devtools/pull/3840)
* Delete flutter_widget.dart [#3846](https://github.com/flutter/devtools/pull/3846)
* Migrate memory_events_pane.dart to null safety [#3844](https://github.com/flutter/devtools/pull/3844)
* Migrate memory_android_chart.dart to null safety [#3845](https://github.com/flutter/devtools/pull/3845)
* Migrate memory_analyzer to null safety [#3843](https://github.com/flutter/devtools/pull/3843)
* Convert memory_vm_chart to null safety [#3841](https://github.com/flutter/devtools/pull/3841)
* Update memory_filter.dart [#3842](https://github.com/flutter/devtools/pull/3842)
* Migrate memory_snapshot_models.dart to null safety [#3824](https://github.com/flutter/devtools/pull/3824)
* Columns [#3836](https://github.com/flutter/devtools/pull/3836)
* Export `Storage` class and create new `MockStorage` class for testing [#3837](https://github.com/flutter/devtools/pull/3837)
* Migrate memory_filter.dart to null safety [#3831](https://github.com/flutter/devtools/pull/3831)
* Migrate memory_tracker_model to null safety [#3830](https://github.com/flutter/devtools/pull/3830)
* Split logging_screen [#3833](https://github.com/flutter/devtools/pull/3833)
* Migrate screens/profiler code to null safety [#3829](https://github.com/flutter/devtools/pull/3829)
* Migrate memory_allocation_table_view.dart to null safety [#3822](https://github.com/flutter/devtools/pull/3822)
* Migrate logging_controller.dart to null safety [#3804](https://github.com/flutter/devtools/pull/3804)
* Migrate memory_allocation_table_data.dart to null safety [#3821](https://github.com/flutter/devtools/pull/3821)
* Migrate memory_graph_model.dart to null safety [#3820](https://github.com/flutter/devtools/pull/3820)
* Migrate memory_protocol.dart to null safety [#3815](https://github.com/flutter/devtools/pull/3815)
* Move shared code into devtools_shared [#3827](https://github.com/flutter/devtools/pull/3827)
* Migrate VM Tools screens to be null safe [#3818](https://github.com/flutter/devtools/pull/3818)
* Migrate memory_timeline to null safety [#3819](https://github.com/flutter/devtools/pull/3819)
* Update chart_controller.dart [#3817](https://github.com/flutter/devtools/pull/3817)
* Migrate isolate_manager to null safety [#3792](https://github.com/flutter/devtools/pull/3792)
* Remove internal Flutter Web warning [#3816](https://github.com/flutter/devtools/pull/3816)
* Migrate memory_controller.dart to null safety [#3795](https://github.com/flutter/devtools/pull/3795)
* Migrate chart.dart to null safety [#3796](https://github.com/flutter/devtools/pull/3796)
* Update vm_service_logger.dart [#3798](https://github.com/flutter/devtools/pull/3798)
* Migrate http_request_data.dart to null safety [#3779](https://github.com/flutter/devtools/pull/3779)

## 2.11.4
* Prep for 2.11.4 release [#3810](https://github.com/flutter/devtools/pull/3810)
* Fix bug with release notes viewer [#3811](https://github.com/flutter/devtools/pull/3811)
* Try downgraded patch versions until we find release notes [#3809](https://github.com/flutter/devtools/pull/3809)
* Add instructions and functionality for testing new release notes [#3803](https://github.com/flutter/devtools/pull/3803)
* Fix null assertion in profile mode [#3808](https://github.com/flutter/devtools/pull/3808)

## 2.11.3
* Check for CHROME_PATH env variable in devtools_shared [#3805](https://github.com/flutter/devtools/pull/3805)

## 2.11.2
* Prep for 2.11.2 release [#3791](https://github.com/flutter/devtools/pull/3791)
* Migrate chart_trace.dart to null safety [#3782](https://github.com/flutter/devtools/pull/3782)
* Fix selection issue if file is already visible in program explorer [#3794](https://github.com/flutter/devtools/pull/3794) 
* Automatic scrolling in the Program Explorer [#3786](https://github.com/flutter/devtools/pull/3786)
* Migrate analytics code to null-safety [#3790](https://github.com/flutter/devtools/pull/3790)
* Migrate isolate_state.dart to null safety [#3781](https://github.com/flutter/devtools/pull/3781)
* Migrate memory_service.dart to null safety [#3783](https://github.com/flutter/devtools/pull/3783)
* Update wrappers.dart [#3785](https://github.com/flutter/devtools/pull/3785)
* Fix type warnings from GA [#3789](https://github.com/flutter/devtools/pull/3789)
* Add missing custom dimensions to GTag exceptions [#3787](https://github.com/flutter/devtools/pull/3787)
* Add missing analytics screen event for Provider page [#3788](https://github.com/flutter/devtools/pull/3788)
* Migrate test utils to null safety [#3784](https://github.com/flutter/devtools/pull/3784)
* Move vm_developer to screens [#3778](https://github.com/flutter/devtools/pull/3778)
* Migrate conditional_screen.dart to null safety [#3736](https://github.com/flutter/devtools/pull/3736)
* Migrate drag_and_drop to null safety [#3744](https://github.com/flutter/devtools/pull/3744)
* Split isolate_manager to simplify migration to null safety [#3765](https://github.com/flutter/devtools/pull/3765)
* Migrate flame_chart to null safety [#3738](https://github.com/flutter/devtools/pull/3738)
* Migrate import_export to null safety [#3749](https://github.com/flutter/devtools/pull/3749)
* Migrate notifications to null saftety [#3751](https://github.com/flutter/devtools/pull/3751)
* Convert server to null safety [#3752](https://github.com/flutter/devtools/pull/3752)
* Migrate info_controller to null safety [#3742](https://github.com/flutter/devtools/pull/3742)
* Migrate treemap.dart to null safety [#3739](https://github.com/flutter/devtools/pull/3739)
* Migrate chart_controller to null safety [#3737](https://github.com/flutter/devtools/pull/3737)
* Migrate service_extension_manager.dart to null safety [#3730](https://github.com/flutter/devtools/pull/3730)
* Migrate filter.dart to null safety [#3734](https://github.com/flutter/devtools/pull/3734)
* Migrate framework_initialize to null safety [#3746](https://github.com/flutter/devtools/pull/3746)
* Migrate sse to null safety [#3753](https://github.com/flutter/devtools/pull/3753)
* Migrate file to null safety [#3745](https://github.com/flutter/devtools/pull/3745)
* Convert url to null safety [#3754](https://github.com/flutter/devtools/pull/3754)
* Convert extension_points to null safety [#3755](https://github.com/flutter/devtools/pull/3754)
* Migrate host_platform to null safety [#3747](https://github.com/flutter/devtools/pull/3747)
* Migrate ide_theme to null safety [#3748](https://github.com/flutter/devtools/pull/3748)
* Migrate devtools_test to unsound null safety [#3763](https://github.com/flutter/devtools/pull/3763)
* Use mouse to select files in file opener [#3758](https://github.com/flutter/devtools/pull/3758)
* Migrate launch_url.dart to null safety [#3750](https://github.com/flutter/devtools/pull/3750)
* Migrate framework_core to null safety [#3743](https://github.com/flutter/devtools/pull/3743)
* Update http_service.dart [#3741](https://github.com/flutter/devtools/pull/3741)
* Migrate http to null safety [#3740](https://github.com/flutter/devtools/pull/3740)
* Migrate table.dart to null safety [#3686](https://github.com/flutter/devtools/pull/3686)
* Move screen related code to the folder 'screens' [#3733](https://github.com/flutter/devtools/pull/3733)
* Update service_extension_widgets.dart [#3735](https://github.com/flutter/devtools/pull/3735)
* Migrate icons.dart to null safety [#3724](https://github.com/flutter/devtools/pull/3724)
* Migrate service_extension_widgets.dart to null safety [#3722](https://github.com/flutter/devtools/pull/3722)
* Update hover.dart [#3725](https://github.com/flutter/devtools/pull/3725)
* Migrate service_manager to null safety [#3729](https://github.com/flutter/devtools/pull/3729)
* Migrate tab.dart to null safety [#3721](https://github.com/flutter/devtools/pull/3721)
* Migrate label to null safety [#3723](https://github.com/flutter/devtools/pull/3723)
* Migrate vm_flag_widgets.dart to null safety [#3720](https://github.com/flutter/devtools/pull/3720)
* Migrate gtags.dart to null safety [#3726](https://github.com/flutter/devtools/pull/3726)
* Migrate vm_service_wrapper.dart to null safety [#3714](https://github.com/flutter/devtools/pull/3714)
* Add line numbers to CPU stack frame uris [#3718](https://github.com/flutter/devtools/pull/3718)
* Migrate search and utils to null safety [#3713](https://github.com/flutter/devtools/pull/3713)
* Migrate colors.dart to null safety [#3715](https://github.com/flutter/devtools/pull/3715)
* Migrate utils.dart to null safety [#3689](https://github.com/flutter/devtools/pull/3689)
* Migrate tree.dart to null safety [#3688](https://github.com/flutter/devtools/pull/3688)
* Move service related functionality to separate folder [#3708](https://github.com/flutter/devtools/pull/3708)
* Remove double loop when initializing thread names [#3707](https://github.com/flutter/devtools/pull/3707)
* Fix tag_version script [#3706](https://github.com/flutter/devtools/pull/3706)
* Keep mapping of thread ids to thread names up to date [#3603](https://github.com/flutter/devtools/pull/3603)
* Migrate vm_flags.dart to null safety [#3690](https://github.com/flutter/devtools/pull/3690)

## 2.11.1
* Prep for 2.11.1 release [#3717](https://github.com/flutter/devtools/pull/3717)
* Update CLI test driver with correct Dart VM Service prefix string [#3716](https://github.com/flutter/devtools/pull/3716)

## 2.11.0
* Fix some issues preventing the google3 roll [#3702](https://github.com/flutter/devtools/pull/3702)
* Update the generate_changelog tool [#3698](https://github.com/flutter/devtools/pull/3698)
* Remove dependency on package:pedantic [#3697](https://github.com/flutter/devtools/pull/3697)
* Changes to enable devtools server tests to run on DDS [#3696](https://github.com/flutter/devtools/pull/3696)
* Add inspector tab switch analytics and fix regression with network screen tabs [#3694](https://github.com/flutter/devtools/pull/3694)
* Migrate table_data.dart to null safety [#3685](https://github.com/flutter/devtools/pull/3685)
* Migrate survey.dart to null safety [#3684](https://github.com/flutter/devtools/pull/3684)
* Make fractions final [#3693](https://github.com/flutter/devtools/pull/3693)
* Migrate split.dart to null safety [#3682](https://github.com/flutter/devtools/pull/3682)
* Update debugger_controller.dart [#3692](https://github.com/flutter/devtools/pull/3692)
* Migrate service.dart to null safety [#3679](https://github.com/flutter/devtools/pull/3679)
* Migrate snapshot_screen.dart to null safety [#3680](https://github.com/flutter/devtools/pull/3680)
* Migrate service_registrations.dart to null safety [#3678](https://github.com/flutter/devtools/pull/3678)
* Fix dart doc for SnapshotScreenBody class [#3681](https://github.com/flutter/devtools/pull/3681)
* Delete legacy performance code and show a warning for old flutter versions [#3676](https://github.com/flutter/devtools/pull/3676)
* Migrate service_extensions.dart to null safety [#3669](https://github.com/flutter/devtools/pull/3669)
* Migrate server_api_client.dart to null safety [#3668](https://github.com/flutter/devtools/pull/3668)
* Migrate scaffold.dart to null safety [#3666](https://github.com/flutter/devtools/pull/3666)
* Fix build_release.sh script [#3675](https://github.com/flutter/devtools/pull/3675)
* Migrate routing.dart to null safety [#3665](https://github.com/flutter/devtools/pull/3665)
* Migrate screen.dart to null safety [#3667](https://github.com/flutter/devtools/pull/3667)
* Fix enum parsing [#3672](https://github.com/flutter/devtools/pull/3672)
* Migrate notifications.dart to null safety [#3661](https://github.com/flutter/devtools/pull/3661)
* Migrate preferences to null safety [#3663](https://github.com/flutter/devtools/pull/3663)
* Remove outdated Flutter Version checks in the Inspector [#3671](https://github.com/flutter/devtools/pull/3671)
* Migrate history_viewport.dart to null safety [#3657](https://github.com/flutter/devtools/pull/3657)
* Migrate release_notes.dart to null safety [#3664](https://github.com/flutter/devtools/pull/3664)
* Remove pub warning [#3670](https://github.com/flutter/devtools/pull/3670)
* Migrate landing_screen.dart to null safety [#3659](https://github.com/flutter/devtools/pull/3659)
* Migrate eval_on_dart_library to null safety [#3654](https://github.com/flutter/devtools/pull/3654)
* Migrate initializer to null safety [#3658](https://github.com/flutter/devtools/pull/3658)
* Update navigation.dart [#3660](https://github.com/flutter/devtools/pull/3660)
* Migrate error_badge_manager.dart to null safety [#3653](https://github.com/flutter/devtools/pull/3653)
* Update flex_split_column.dart [#3656](https://github.com/flutter/devtools/pull/3656)
* Update file_import.dart [#3655](https://github.com/flutter/devtools/pull/3655)
* Migrate dialogs.dart to null safety [#3652](https://github.com/flutter/devtools/pull/3652)
* Migrate device_dialog to null safety [#3651](https://github.com/flutter/devtools/pull/3651)
* Migrate common_widgets.dart to null safety [#3647](https://github.com/flutter/devtools/pull/3647)
* Migrate console_service.dart to null safety [#3650](https://github.com/flutter/devtools/pull/3650)
* Update console.dart [#3648](https://github.com/flutter/devtools/pull/3648)
* Migrate banner_messages.dart to null safety [#3646](https://github.com/flutter/devtools/pull/3646)
* Migrate utils to be null safe [#3645](https://github.com/flutter/devtools/pull/3645)
* Migrate theme.dart to be null safe [#3633](https://github.com/flutter/devtools/pull/3633)
* Migrate connected_app.dart to null safety [#3642](https://github.com/flutter/devtools/pull/3642)
* Migrate collapsible_mixin.dart to null safety [#3641](https://github.com/flutter/devtools/pull/3641)
* Migrate app_error_handling.dart to null safety [#3640](https://github.com/flutter/devtools/pull/3640)
* Split utils to simplify migration to null safety [#3639](https://github.com/flutter/devtools/pull/3639)
* Create README.md [#3643](https://github.com/flutter/devtools/pull/3643)
* Update CONTRIBUTING.md [#3638](https://github.com/flutter/devtools/pull/3638)
* Migrate some libraries to be null safe [#3632](https://github.com/flutter/devtools/pull/3632)
* Add null safety comment to inspector_polyfill_script.dart [#3631](https://github.com/flutter/devtools/pull/3631)
* Null safety for some primitives [#3622](https://github.com/flutter/devtools/pull/3622)
* Make trees.dart null safe [#3626](https://github.com/flutter/devtools/pull/3626)
* Migrate linked_scroll_controller to null safety [#3623](https://github.com/flutter/devtools/pull/3623)
* Update memory_graph_model.dart [#3630](https://github.com/flutter/devtools/pull/3630)
* Update auto_dispose.dart [#3628](https://github.com/flutter/devtools/pull/3628)
* Run DevTools tests against a Flutter test app running on Flutter master [#3572](https://github.com/flutter/devtools/pull/3572)
* Update syntax_highlighting.dart [#3625](https://github.com/flutter/devtools/pull/3625)
* Migrate [#3624](https://github.com/flutter/devtools/pull/3624)
* Delete `devtools_server` and `devtools` packages [#3617](https://github.com/flutter/devtools/pull/3617)
* Migrate auto_dispose to null safety [#3621](https://github.com/flutter/devtools/pull/3621)
* Update SDK to 2.12 [#3618](https://github.com/flutter/devtools/pull/3618)
* Update ansicolor to nullsafe version [#3600](https://github.com/flutter/devtools/pull/3600)
* Move linked_scroll_controller.dart from flutter_widgets to primitives [#3615](https://github.com/flutter/devtools/pull/3615)
* File opener UX improvements [#3612](https://github.com/flutter/devtools/pull/3612)
* Update dependencies [#3614](https://github.com/flutter/devtools/pull/3614)
* Remove flutter client ID from DevTools survey query parameters [#3613](https://github.com/flutter/devtools/pull/3613)
* Assorted cleanup for `_AutoCompleteSearchField` [#3611](https://github.com/flutter/devtools/pull/3611)

## 2.10.0
* Remove unused file and move message_bus to primitives/ directory [#3609](https://github.com/flutter/devtools/pull/3609)
* Update README.md [#3606](https://github.com/flutter/devtools/pull/3606)
* Focus workaround so that keyboard shorcuts always work [#3602](https://github.com/flutter/devtools/pull/3602)
* Update README.md [#3605](https://github.com/flutter/devtools/pull/3605)
* Add asserts / logging to catch when script ref is null [#3601](https://github.com/flutter/devtools/pull/3601)
* Show warning for internal Flutter Web apps [#3597](https://github.com/flutter/devtools/pull/3597)
* Fix a null ref in CPU Profile when using offline snapshots with no connection [#3596](https://github.com/flutter/devtools/pull/3596)
* Move libraries from root to subfolders [#3594](https://github.com/flutter/devtools/pull/3594)
* Update release_notes.dart [#3592](https://github.com/flutter/devtools/pull/3592)
* Return project.pbxproj [#3591](https://github.com/flutter/devtools/pull/3591)
* Update .gitignore [#3589](https://github.com/flutter/devtools/pull/3589)
* Use parsed devtools version in release notes viewer [#3590](https://github.com/flutter/devtools/pull/3590)
* Fixes fatal error when you try to filter logs twice [#3588](https://github.com/flutter/devtools/pull/3588)
* Manually set R/W permissions on canvaskit binaries [#3586](https://github.com/flutter/devtools/pull/3586)
* Adds multi-token file search, and prioritizes file name matches over full path matches [#3582](https://github.com/flutter/devtools/pull/3582)
* Make devtools_test a minimal package by removing all unnecessary files [#3581](https://github.com/flutter/devtools/pull/3581)
* Use canvaskit that is packaged with Flutter SDK [#3580](https://github.com/flutter/devtools/pull/3580)
* Update inspector goldens [#3583](https://github.com/flutter/devtools/pull/3583)
* Refactors file search to use `FileSearchResults` and `FileQuery` classes [#3573](https://github.com/flutter/devtools/pull/3573)
* Prepare for 2.10.0-dev.1 release [#3578](https://github.com/flutter/devtools/pull/3578)
* Make Canvaskit binaries read/write-able for releases [#3577](https://github.com/flutter/devtools/pull/3577)
* Update CONTRIBUTING.md [#3570](https://github.com/flutter/devtools/pull/3570)
* Quick fix to survey url parsing bug [#3574](https://github.com/flutter/devtools/pull/3574)
* Fix deprecation warning and bump dds dependency [#3575](https://github.com/flutter/devtools/pull/3575)
* Adds a utility method to transform AutoCompleteMatch [#3569](https://github.com/flutter/devtools/pull/3569)
* Add FrameTimeVisualizer to janky frame analysis view [#3566](https://github.com/flutter/devtools/pull/3566)
* Wait for kIsolateRunnable event before loading isolate state [#3564](https://github.com/flutter/devtools/pull/3564)
* Only print the inspector search stats in debug mode [#3562](https://github.com/flutter/devtools/pull/3562)
* Bump version to 2.9.3 [#3563](https://github.com/flutter/devtools/pull/3563)
* Inspector widget selection improvements [#3489) (#3525](https://github.com/flutter/devtools/pull/3489) (#3525)
* Add placeholder for a custom mutation observer script [#3558](https://github.com/flutter/devtools/pull/3558)
* Stop using package:intl in devtools_server [#3544](https://github.com/flutter/devtools/pull/3544)
* Remove debug prints from devtools_shared [#3548](https://github.com/flutter/devtools/pull/3548)

## 2.9.2+1
* Quick fix to survey url parsing bug [#3574](https://github.com/flutter/devtools/pull/3574)

## 2.9.2
* Prepare for 2.9.2 release [#3547](https://github.com/flutter/devtools/pull/3547)
* Update `package:vm_service` to `^8.1.0` [#3545](https://github.com/flutter/devtools/pull/3545)
* Add --version flag to DevTools server command [#3546](https://github.com/flutter/devtools/pull/3546)
* Display release notes directly in DevTools [#3542](https://github.com/flutter/devtools/pull/3542)
* Refactors `AutoDisposeMixin` to have separate cancel methods for listeners, stream subscriptions, and focus nodes [#3540](https://github.com/flutter/devtools/pull/3540)
* Fix a parsing bug with the SemanticVersion class [#3539](https://github.com/flutter/devtools/pull/3539)
* Follow best practices for creating FocusNode objects [#3532](https://github.com/flutter/devtools/pull/3532)
* Apply UX suggestions to frame analysis icon [#3536](https://github.com/flutter/devtools/pull/3536)
* Create `DualValueListenableBuilder` widget and clean up ValueListenableBuilders to user `child` parameter [#3533](https://github.com/flutter/devtools/pull/3533)
* Use proper frame id to number frames in the performance page [#3535](https://github.com/flutter/devtools/pull/3535)
* Fix state issue with CpuProfiler user tags [#3531](https://github.com/flutter/devtools/pull/3531)
* Fixes program explorer bug on hot restart [#3527](https://github.com/flutter/devtools/pull/3527)
* Escape text directional Unicode [#3529](https://github.com/flutter/devtools/pull/3529)
* Fix bug with search [#3528](https://github.com/flutter/devtools/pull/3528)
* Add frame numbers to the flutter frames chart in the performance page [#3526](https://github.com/flutter/devtools/pull/3526)
* Add selection analytics for NetworkScreen [#3360](https://github.com/flutter/devtools/pull/3360)
* Do not wait on stream listening during start up [#3358](https://github.com/flutter/devtools/pull/3358)
* Add analytics/analytics.dart export to devtools_app.dart [#3523](https://github.com/flutter/devtools/pull/3523)
* Add is_embedded dimension to DevTools analytics [#3522](https://github.com/flutter/devtools/pull/3522)

## 2.9.1
* Fix build script logic to download canvaskit [#3519](https://github.com/flutter/devtools/pull/3519)

## 2.9.0
* Fix bugs with performance page search and improve performance [#3515](https://github.com/flutter/devtools/pull/3515)
* Refactor `Variable` class and rename it to `DartObjectNode` [#3513](https://github.com/flutter/devtools/pull/3513)
* Add skeleton for frame analysis feature [#3509](https://github.com/flutter/devtools/pull/3509)
* Add VSCode config files to gitignore [#3512](https://github.com/flutter/devtools/pull/3512)
* Update survey metadata url to match new website location [#3511](https://github.com/flutter/devtools/pull/3511)
* Fixes VM service breakage due to deprecated method [#3510](https://github.com/flutter/devtools/pull/3510)
* Improve inspecting large `Map` and `List` types [#3497](https://github.com/flutter/devtools/pull/3497)
* Update flutter version for bots to latest flutter beta [#3508](https://github.com/flutter/devtools/pull/3508)
* VM service wrapper implements noSuchMethod [#3505](https://github.com/flutter/devtools/pull/3505)
* Add DevToolsIconButton helper widget [#3504](https://github.com/flutter/devtools/pull/3504)
* Add a button for opening a file in empty state page [#3501](https://github.com/flutter/devtools/pull/3501)
* Create `BlinkingIcon` helper widget [#3496](https://github.com/flutter/devtools/pull/3496)
* Bump version to 2.8.0-dev.1 [#3495](https://github.com/flutter/devtools/pull/3495)
* Track whether an app is a Flutter Web app in analytics [#3494](https://github.com/flutter/devtools/pull/3494)
* Create rich tooltip for Flutter frames in the performance view [#3493](https://github.com/flutter/devtools/pull/3493)
* Add new 'invokeServiceMethodWithArgReturningNode' helper to 'ObjectGroupBase' [#3492](https://github.com/flutter/devtools/pull/3492)
* Add richMessage support to DevToolsTooltip widget [#3491](https://github.com/flutter/devtools/pull/3491)
* Add integration test to verify the expected vm service calls at startup [#3443](https://github.com/flutter/devtools/pull/3443)
* Add support for vm_service 7.4.0 [#3490](https://github.com/flutter/devtools/pull/3490)
* Update errorTextColor to meet color contrast requirements [#3488](https://github.com/flutter/devtools/pull/3488)
* Fix test flakes with the service manager [#3474](https://github.com/flutter/devtools/pull/3474)
* Do not focus a line in the code view when no outlineNode is selected [#3487](https://github.com/flutter/devtools/pull/3487)
* Fix typos [#3486](https://github.com/flutter/devtools/pull/3486)
* Remove package meta dependency and imports [#3484](https://github.com/flutter/devtools/pull/3484)
* Add support for selecting objects in the program explorer outline view [#3480](https://github.com/flutter/devtools/pull/3480)

## 2.8.0
* Don't register service worker when running DevTools locally [#3476](https://github.com/flutter/devtools/pull/3476)
* [Cleanup] Moved `[set/get]PubRootDirectories` functions from `InspectorServiceBase` to `InspectorService` [#3478](https://github.com/flutter/devtools/pull/3478)
* Improve startup performance of DevTools by using lazy initialization for debugger and console service [#3468](https://github.com/flutter/devtools/pull/3468)
* Fix bug with version parsing [#3473](https://github.com/flutter/devtools/pull/3473)
* Add new `inspectorServiceProvider()` function to `extensions_base.dart` [#3470](https://github.com/flutter/devtools/pull/3470)
* Add inspector/diagnostics.dart and split.dart exports to devtools_app.dart [#3469](https://github.com/flutter/devtools/pull/3469)
* Refactor InspectorServiceBase and ObjectGroupBase out of InspectorService and ObjectGroup [#3465](https://github.com/flutter/devtools/pull/3465)
* Add a warning to stop launching on pub for DevTools version 2.8.0 [#3464](https://github.com/flutter/devtools/pull/3464)
* Keyboard shortcuts are set on the top-level scaffold [#3458](https://github.com/flutter/devtools/pull/3458)
* Adds caching to speed up the expression evaluation autocomplete [#3463](https://github.com/flutter/devtools/pull/3463)
* Cleanup "More Debugging Options" button on Performance page [#3461](https://github.com/flutter/devtools/pull/3461)
* Add Track Paints and Track Layouts toggles to the performance page [#3451](https://github.com/flutter/devtools/pull/3451)
* Reland `ProgramExplorer` [#3448](https://github.com/flutter/devtools/pull/3448)
* Expression evaluation autocomplete overlay is positioned over the last `.` in the expression [#3449](https://github.com/flutter/devtools/pull/3449)
* Add debug disable layer toggles to the Performance page [#3441](https://github.com/flutter/devtools/pull/3441)
* Add service worker to cache `main.dart.js` and everything in `/assets` [#3325](https://github.com/flutter/devtools/pull/3325)
* Do not fetch timeline stream values for web apps [#3446](https://github.com/flutter/devtools/pull/3446)
* Refactors search to have private _SearchField and _AutoCompleteSearchField widgets [#3442](https://github.com/flutter/devtools/pull/3442)
* Fix 'unnecessary import' warnings [#3440](https://github.com/flutter/devtools/pull/3440)
* Listen to timeline stream changes from the VM service and cleanup perf settings [#3432](https://github.com/flutter/devtools/pull/3432)
* Update widget_icons changelog to match version number [#3437](https://github.com/flutter/devtools/pull/3437)
* Update git url for widget_icons pubspec [#3436](https://github.com/flutter/devtools/pull/3436)
* Tweak positioning of file picker [#3421](https://github.com/flutter/devtools/pull/3421)
* Clean up pubspec files [#3431](https://github.com/flutter/devtools/pull/3431)
* Run serveRequests in an error zone and log errors [#3429](https://github.com/flutter/devtools/pull/3429)
* Widget Icons package added [#3409](https://github.com/flutter/devtools/pull/3409)
* Update DevTools release instructions [#3428](https://github.com/flutter/devtools/pull/3428)
* Expose more common devtools_app source files via devtools_app.dart [#3427](https://github.com/flutter/devtools/pull/3427)

## 2.7.0
* Fix file:line:col color fixed (#3249) [#3365](https://github.com/flutter/devtools/pull/3365)
* Moved test helper code from "test/support" to a new "devtools_test" package [#3406](https://github.com/flutter/devtools/pull/3406)
* Upgrade to DDS version 2.1.3 [#3404](https://github.com/flutter/devtools/pull/3404)
* Update flutter-version.txt to latest dev [#3392](https://github.com/flutter/devtools/pull/3392)
* Add connected app information to offline snapshots [#3397](https://github.com/flutter/devtools/pull/3397)
* Added some Hyperlinks [#3403](https://github.com/flutter/devtools/pull/3403)
* Prepare version 2.6.1-dev.2 [#3402](https://github.com/flutter/devtools/pull/3402)
* Always show the vertical scrollbar [#3401](https://github.com/flutter/devtools/pull/3401)
* Disable default scrollbar behavior on web [#3393](https://github.com/flutter/devtools/pull/3393)
* Highlight matches in the file picker dropdown [#3384](https://github.com/flutter/devtools/pull/3384)
* Add class names to CPU stack frames in the profiler [#3385](https://github.com/flutter/devtools/pull/3385)
* Changed the issue link to go straight to filing an issue (#2915) [#3373](https://github.com/flutter/devtools/pull/3373)
* Calculate tile size for the autocomplete widget [#3377](https://github.com/flutter/devtools/pull/3377)
* Improves searching in the file picker [#3371](https://github.com/flutter/devtools/pull/3371)
* Remove unused class that is causing compiler issues [#3380](https://github.com/flutter/devtools/pull/3380)
* Move 'Step Over' button before 'Step in' [#3379](https://github.com/flutter/devtools/pull/3379)
* Prepare for v2.6.1-dev.1 release [#3370](https://github.com/flutter/devtools/pull/3370)
* Merge InspectorTreeControllerFlutter and superclass into single InspectorTreeController class [#3367](https://github.com/flutter/devtools/pull/3367)
* Moves the file opener out of a dialog [#3354](https://github.com/flutter/devtools/pull/3354)
* Add multi-isolate support to the CPU profiler [#3362](https://github.com/flutter/devtools/pull/3362)
* Add ability to profile app start up and improve CPU profile caching [#3357](https://github.com/flutter/devtools/pull/3357)
* Send event to dwds when debug screen is ready [#3355](https://github.com/flutter/devtools/pull/3355)
* Add analytics for app disconnects [#3356](https://github.com/flutter/devtools/pull/3356)
* Use "Command" instead of special character ⌘ on web [#3353](https://github.com/flutter/devtools/pull/3353)
* Enable the file opener [#3350](https://github.com/flutter/devtools/pull/3350)
* Revert "Don't wait on stream listening in DevTools start up (#3333)" [#3351](https://github.com/flutter/devtools/pull/3351)
* Don't wait on stream listening in DevTools start up [#3333](https://github.com/flutter/devtools/pull/3333)
* Add timing analytics for debugger page load [#3346](https://github.com/flutter/devtools/pull/3346)
* Add TODO to inspector controller [#3347](https://github.com/flutter/devtools/pull/3347)
* Fix some state management issues in the inspector [#3339](https://github.com/flutter/devtools/pull/3339)
* Adds a basic dialog for opening a file [#3342](https://github.com/flutter/devtools/pull/3342)
* Feat: Copy Button for Call stack [#3334](https://github.com/flutter/devtools/pull/3334)
* Add custom dimension and metric instructions to analytics config [#3341](https://github.com/flutter/devtools/pull/3341)
* Cache the results of `getVersion` and `getIsolate` on startup [#3309](https://github.com/flutter/devtools/pull/3309)
* Fix network_model_test.dart breaking the bots [#3340](https://github.com/flutter/devtools/pull/3340)
* Fix some formatting errors in the changelog [#3338](https://github.com/flutter/devtools/pull/3338)
* Restructure analytics code so that the AnalyticsController can be tested [#3336](https://github.com/flutter/devtools/pull/3336)
* Add is_external_build dimension to analytics [#3337](https://github.com/flutter/devtools/pull/3337)
* Fix grey panels when selecting some HTTP Requests [#3328](https://github.com/flutter/devtools/pull/3328)
* Remove filter text field from ScriptPicker [#3319](https://github.com/flutter/devtools/pull/3319)

## 2.6.0
* Fix analytics initialization [#3323](https://github.com/flutter/devtools/pull/3323)
* Update CPU profiler colors to make them accessible [#3324](https://github.com/flutter/devtools/pull/3324)
* Polish for scaling the DevTools UI for large font sizes [#3316](https://github.com/flutter/devtools/pull/3316)
* Add a key set command for opening a file [#3315](https://github.com/flutter/devtools/pull/3315)
* Add reportLines parameter to getSourceReport [#3322](https://github.com/flutter/devtools/pull/3322)
* Revert "Don't wait on listening for streams in DevTools startup [#3321](https://github.com/flutter/devtools/pull/3321)
* Don't wait on listening for streams in DevTools startup [#3320](https://github.com/flutter/devtools/pull/3320)
* Fix filtering bug in CPU profiler [#3313](https://github.com/flutter/devtools/pull/3313)
* Support custom font sizes better across all pages [#3299](https://github.com/flutter/devtools/pull/3299)
* Color stack frames by categories: native, dart core, flutter core [#3310](https://github.com/flutter/devtools/pull/3310)
* Add warning for ios profiling issue and link to workaround [#3311](https://github.com/flutter/devtools/pull/3311)
* Tweak how we assign timeline events to flutter frames [#3297](https://github.com/flutter/devtools/pull/3297)
* Update few icons in Flutter Inspector [#3305](https://github.com/flutter/devtools/pull/3305)
* Cancel timeline polling timer when the vmService is closed [#3304](https://github.com/flutter/devtools/pull/3304)
* Hide the CPU profiler filter button when the summary tab is selected [#3303](https://github.com/flutter/devtools/pull/3303)
* Fix js issue with `GtagEventDevTools` constructor [#3301](https://github.com/flutter/devtools/pull/3301)
* Add a scrollbar for horizontal scrolling of source files in the debugger [#3262](https://github.com/flutter/devtools/pull/3262)
* Cleanup console with eval that scrolls and less busy splitter [#3298](https://github.com/flutter/devtools/pull/3298)
* Fix a couple bugs for offline imports [#3296](https://github.com/flutter/devtools/pull/3296)
* Add analytics to performance and cpu profiler screens [#3281](https://github.com/flutter/devtools/pull/3281)
* Clear HttpProfile on VM when pressing 'Clear' on network page [#3294](https://github.com/flutter/devtools/pull/3294)
* Updated macos/Runner.xcodeproj/project.pbxproj [#3293](https://github.com/flutter/devtools/pull/3293)
* Fix selection bug in the network profiler [#3287](https://github.com/flutter/devtools/pull/3287)
* Sort timeline events before processing [#3285](https://github.com/flutter/devtools/pull/3285)
* Fix links opening when embedded in VSCode [#3252](https://github.com/flutter/devtools/pull/3252)
* Add a hidden arg to the devtools command [#3282](https://github.com/flutter/devtools/pull/3282)
* Add a package:args Command implementation [#3280](https://github.com/flutter/devtools/pull/3280)
* Add some analytics to the memory screen and clean up code [#3272](https://github.com/flutter/devtools/pull/3272)
* Add analytics to documentation links in the status line [#3273](https://github.com/flutter/devtools/pull/3273)
* Some syntax modifications to the analytics dimensions [#3266](https://github.com/flutter/devtools/pull/3266)
* Fix type errors in Filter code [#3277](https://github.com/flutter/devtools/pull/3277)
* Performance improvements for the CPU profiler [#3274](https://github.com/flutter/devtools/pull/3274)
* Fix missing network screen documentation link [#3268](https://github.com/flutter/devtools/pull/3268)
* Add analytics to settings options [#3267](https://github.com/flutter/devtools/pull/3267)
* Refactor Landing screen and add analytics for buttons [#3265](https://github.com/flutter/devtools/pull/3265)
* Changes to when analytics dialog appears and how it sets analytics [#3263](https://github.com/flutter/devtools/pull/3263)
* Adds configuration for running devtools on Linux [#3261](https://github.com/flutter/devtools/pull/3261)
* Support filtering CPU profiles [#3236](https://github.com/flutter/devtools/pull/3236)
* Fix 'not found' icons for ElevatedButton and CircleAvatar [#3258](https://github.com/flutter/devtools/pull/3258)
* Remove some older crash handling support [#3255](https://github.com/flutter/devtools/pull/3255)
* Remove a no longer used compile step [#3253](https://github.com/flutter/devtools/pull/3253)
* Delete devtools_testing package [#3250](https://github.com/flutter/devtools/pull/3250)
* Show HTTP POST request body [#3233](https://github.com/flutter/devtools/pull/3233)

## 2.5.0
* Fix some render overflow errors and cleanup [#3246](https://github.com/flutter/devtools/pull/3246)
* Update the contributing documentation [#3245](https://github.com/flutter/devtools/pull/3245)
* New widget icons and alignment added [#3215](https://github.com/flutter/devtools/pull/3215)
* Add rich tooltips to debug toggles [#3183](https://github.com/flutter/devtools/pull/3183)
* Add text previews to widget tree [#3218](https://github.com/flutter/devtools/pull/3218)
* Prepare for v2.5.0 release [#3235](https://github.com/flutter/devtools/pull/3235)
* Improve generate_changelog script [#3239](https://github.com/flutter/devtools/pull/3239)
* Finish converting tool/ to null safety [#3237](https://github.com/flutter/devtools/pull/3237)
* Fix debug buttons layout overflow [#3224](https://github.com/flutter/devtools/pull/3224)
* Make return key submit connect form [#3228](https://github.com/flutter/devtools/pull/3228)
* Minor analysis updates to the repo [#3225](https://github.com/flutter/devtools/pull/3225)
* Always build devtools from a specified, specific sdk version [#3216](https://github.com/flutter/devtools/pull/3216)
* Refactor CpuProfileData in preparation for filtering support [#3220](https://github.com/flutter/devtools/pull/3220)
* Add focus node names to help debug focus node issues [#3217](https://github.com/flutter/devtools/pull/3217)
* Process stats for widget rebuild events [#3219](https://github.com/flutter/devtools/pull/3219)
* Fix icon positions in the eval console [#3213](https://github.com/flutter/devtools/pull/3213)
* Polish to the live timeline [#3209](https://github.com/flutter/devtools/pull/3209)
* Rev. the dep on package:vm_service [#3211](https://github.com/flutter/devtools/pull/3211)
* Experimenting with building against a specific flutter sdk [#3197](https://github.com/flutter/devtools/pull/3197)
* Make Flutter Frame timeline live and migrate to the FrameTiming API [#3168](https://github.com/flutter/devtools/pull/3168)
* Add functionality to filter tree data [#3203](https://github.com/flutter/devtools/pull/3203)
* Only run the formatter on the bots for the master channel and add missing VmService method [#3202](https://github.com/flutter/devtools/pull/3202)
* Implement redesign of debug toggle buttons [#3167](https://github.com/flutter/devtools/pull/3167)
* Fix lint that is breaking the build [#3198](https://github.com/flutter/devtools/pull/3198)
* Console land [#3138](https://github.com/flutter/devtools/pull/3138)
* Support more uri params for specifying the service uri [#3161](https://github.com/flutter/devtools/pull/3161)
* Run all integration tests [#3189](https://github.com/flutter/devtools/pull/3189)
* Allow embedding unless specified [#3193](https://github.com/flutter/devtools/pull/3193)
* Eliminate spurious test output spam on missing taps [#3192](https://github.com/flutter/devtools/pull/3192)
* Update release script [#3188](https://github.com/flutter/devtools/pull/3188)

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
