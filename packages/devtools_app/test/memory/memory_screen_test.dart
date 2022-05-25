// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/memory_events_pane.dart';
import 'package:devtools_app/src/screens/memory/memory_heap_tree_view.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/memory_vm_chart.dart';
import 'package:devtools_app/src/screens/memory/panes/controls/constants.dart';
import 'package:devtools_app/src/screens/memory/panes/controls/controls_widgets.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/ui/search.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../matchers/matchers.dart';
import '../test_data/memory.dart';
import '../test_data/memory_allocation.dart';

void main() {
  late MemoryScreen screen;
  late MemoryController controller;
  late FakeServiceManager fakeServiceManager;

  /// Classes to track while testing.
  final classesToTrack = <ClassRef>[];

  void setupTracking(List<ClassHeapDetailStats> classesDetail) {
    for (var classDetail in classesDetail) {
      final tracking = classesToTrack.singleWhereOrNull(
        (element) => element.name == classDetail.classRef.name,
      );
      if (tracking != null) {
        controller.setTracking(classDetail.classRef, true);
      }
    }
  }

  void _setUpServiceManagerForMemory() {
    // Load canned data testHeapSampleData.
    final memoryJson =
        SamplesMemoryJson.decode(argJsonString: testHeapSampleData);
    final allocationJson =
        AllocationMemoryJson.decode(argJsonString: testAllocationData);

    // Use later in the class tracking test.
    if (classesToTrack.isEmpty) {
      for (var classDetails in allocationJson.data) {
        if (classDetails.isStacktraced) {
          classesToTrack.add(classDetails.classRef);
        }
      }
    }

    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(
        memoryData: memoryJson,
        allocationData: allocationJson,
      ),
    );
    when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isFlutterAppNow).thenReturn(true);
    when(fakeServiceManager.connectedApp!.isDartCliAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDebugFlutterAppNow)
        .thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDartWebApp)
        .thenAnswer((_) => Future.value(false));
    setGlobal(ServiceConnectionManager, fakeServiceManager);

    controller.offline.value = true;
    controller.memoryTimeline.offlineData.clear();
    controller.memoryTimeline.offlineData.addAll(memoryJson.data);
  }

  Future<void> pumpMemoryScreen(
    WidgetTester tester, {
    MemoryController? memoryController,
  }) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const MemoryBody(),
        memory: controller = memoryController ?? MemoryController(),
      ),
    );

    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  group('MemoryScreen', () {
    void useHardCodedMonitorTimestamp() {
      // Hard-code a date/time so the golden master check is consistent.
      // April 29, 2021 @ 20:28:33.888
      controller.lastMonitorTimestamp.value =
          DateTime(2021, 4, 29, 20, 28, 33, 888);
    }

    setUp(() async {
      await ensureInspectorDependencies();
      setGlobal(OfflineModeController, OfflineModeController());
      fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp!.isDebugFlutterAppNow)
          .thenReturn(false);
      when(fakeServiceManager.vm.operatingSystem).thenReturn('android');
      when(fakeServiceManager.connectedApp!.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      when(fakeServiceManager.errorBadgeManager.errorCountNotifier('memory'))
          .thenReturn(ValueNotifier<int>(0));
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(IdeTheme, IdeTheme());
      screen = const MemoryScreen();

      expect(MemoryScreen.isDebugging, isFalse);
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Memory'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds proper content for state', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      // Should be collecting live feed.
      expect(controller.offline.value, isFalse);

      // Verify Memory, Memory Source, and Memory Sources content.
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      expect(controller.memorySource, MemoryController.liveFeed);

      controller.isAdvancedSettingsVisible == false
          ? expect(find.text('GC'), findsNothing)
          : expect(find.text('GC'), findsOneWidget);

      expect(find.byType(MemoryVMChart), findsOneWidget);

      expect(controller.memoryTimeline.liveData.isEmpty, isTrue);
      expect(controller.memoryTimeline.offlineData.isEmpty, isTrue);

      // Check memory sources available.
      await tester.tap(find.byKey(sourcesDropdownKey));
      await tester.pump();

      // Should only be one source 'Live Feed' in the popup menu.
      final memorySources = tester.firstWidget(
        find.byKey(
          sourcesKey,
        ),
      ) as Text;

      expect(
        memorySources.data,
        '${controller.memorySourcePrefix}${MemoryController.liveFeed}',
      );
    });

    testWidgetsWithWindowSize('Chart Select Hover Test', windowSize,
        (WidgetTester tester) async {
      const _twoSeconds = Duration(seconds: 2);

      Future<void> pumpAndSettleTwoSeconds() async {
        await tester.pumpAndSettle(_twoSeconds);
      }

      await pumpMemoryScreen(tester);

      // Load canned data.
      _setUpServiceManagerForMemory();

      expect(controller.offline.value, isTrue);

      // Verify default event pane and vm chart exists.
      expect(find.byType(MemoryEventsPane), findsOneWidget);
      expect(find.byType(MemoryVMChart), findsOneWidget);

      expect(controller.memoryTimeline.liveData.isEmpty, isTrue);
      expect(controller.memoryTimeline.offlineData.isEmpty, isFalse);

      controller.refreshAllCharts();
      await pumpAndSettleTwoSeconds();

      expect(controller.memoryTimeline.data.isEmpty, isFalse);

      final data = controller.memoryTimeline.data;

      // Total number of collected HeapSamples.
      expect(data.length, 104);

      await pumpAndSettleTwoSeconds();

      // TODO(terry): Need to fix hover not appearing.
      /*
      final vmChartFinder = find.byKey(MemoryScreen.vmChartKey);
      final vmChart = tester.firstWidget(vmChartFinder) as MemoryVMChart;
      final rect = tester.getRect(vmChartFinder);

      final globalPosition = Offset(rect.right - 100, rect.top + 10);

      vmChart.chartController.tapLocation.value = TapLocation(
        TapDownDetails(
          globalPosition: globalPosition,
          kind: PointerDeviceKind.touch,
        ),
        controller.memoryTimeline.data[35].timestamp,
        35,
      );
      await pumpAndSettleTwoSeconds();
      */

      await expectLater(
        find.byType(MemoryVMChart),
        matchesDevToolsGolden('../goldens/memory_hover_card.png'),
      );

      // Await delay for golden comparison.
      await pumpAndSettleTwoSeconds();
    });

    testWidgetsWithWindowSize('export current memory profile', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      // Verify initial state - collecting live feed.
      expect(controller.offline.value, isFalse);

      final previousMemoryLogs = controller.memoryLog.offlineFiles();

      // Export memory to a memory log file.
      await tester.tap(find.byType(ExportButton));
      await tester.pump();

      expect(controller.offline.value, isFalse);

      expect(controller.memoryTimeline.liveData, isEmpty);
      expect(controller.memoryTimeline.offlineData, isEmpty);

      final currentMemoryLogs = controller.memoryLog.offlineFiles();
      expect(currentMemoryLogs.length, previousMemoryLogs.length + 1);

      // Verify that memory source is still live feed.
      expect(controller.offline.value, isFalse);
    });

    testWidgetsWithWindowSize(
        'switch from live feed and load exported file', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      // Live feed should be default selected.
      expect(controller.memorySource, MemoryController.liveFeed);

      // Expand the memory sources.
      await tester.tap(find.byKey(sourcesDropdownKey));
      await tester.pumpAndSettle();

      // Last item in dropdown list of memory source should be memory log file.
      await tester
          .tap(find.byType(typeOf<SourceDropdownMenuItem<String>>()).last);
      await tester.pump();

      expect(
        controller.memorySource,
        startsWith(MemoryController.logFilenamePrefix),
      );

      final filenames = controller.memoryLog.offlineFiles();
      final filename = filenames.first;

      expect(filename, startsWith(MemoryController.logFilenamePrefix));

      await controller.memoryLog.loadOffline(filename);

      expect(controller.offline.value, isTrue);

      // Remove the memory log, in desktop only version.  Don't want to polute
      // our temp directory when this test runs locally.
      expect(controller.memoryLog.removeOfflineFile(filename), isTrue);
    });

    testWidgetsWithWindowSize('heap tree view', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      final heapSnapShotFinder = find.text('Take Heap Snapshot');

      expect(heapSnapShotFinder, findsOneWidget);

      // Load canned data.
      _setUpServiceManagerForMemory();

      expect(controller.offline.value, isTrue);

      // Verify default event pane and vm chart exists.
      expect(find.byType(MemoryEventsPane), findsOneWidget);
      expect(find.byType(MemoryVMChart), findsOneWidget);

      expect(controller.memoryTimeline.liveData.isEmpty, isTrue);
      expect(controller.memoryTimeline.offlineData.isEmpty, isFalse);

      controller.refreshAllCharts();

      // Await charts to update.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(controller.memoryTimeline.data.isEmpty, isFalse);

      final data = controller.memoryTimeline.data;

      // Total number of collected HeapSamples.
      expect(data.length, 104);

      // Number of VM GCs
      final totalGCEvents = data.where((element) => element.isGC);
      expect(totalGCEvents.length, 46);

      // User initiated GCs
      final totalUserGCEvents =
          data.where((element) => element.memoryEventInfo.isEventGC);
      expect(totalUserGCEvents.length, 3);

      // User initiated Snapshots
      final totalSnapshotEvents =
          data.where((element) => element.memoryEventInfo.isEventSnapshot);
      expect(totalSnapshotEvents.length, 1);

      // Number of auto-Snapshots
      final totalSnapshotAutoEvents =
          data.where((element) => element.memoryEventInfo.isEventSnapshotAuto);
      expect(totalSnapshotAutoEvents.length, 2);

      // Total Allocation Monitor events (many are empty).
      final totalAllocationMonitorEvents = data.where(
        (element) => element.memoryEventInfo.isEventAllocationAccumulator,
      );
      expect(totalAllocationMonitorEvents.length, 81);

      // Number of user initiated allocation monitors
      final startMonitors = totalAllocationMonitorEvents.where(
        (element) => element.memoryEventInfo.allocationAccumulator!.isStart,
      );
      expect(startMonitors.length, 2);

      // Number of accumulator resets
      final resetMonitors = totalAllocationMonitorEvents.where(
        (element) => element.memoryEventInfo.allocationAccumulator!.isReset,
      );
      expect(resetMonitors.length, 1);

      final interval1Min =
          MemoryController.displayIntervalToIntervalDurationInMs(
        ChartInterval.OneMinute,
      );
      expect(interval1Min, 60000);
      final interval5Min =
          MemoryController.displayIntervalToIntervalDurationInMs(
        ChartInterval.FiveMinutes,
      );
      expect(interval5Min, 300000);

      // TODO(terry): Check intervals and autosnapshot does it snapshot same points?
      // TODO(terry): Simulate sample run of liveData filling up?

      // Take a snapshot
      await tester.tap(heapSnapShotFinder);
      await tester.pump();

      final snapshotIconLabel = tester.element(heapSnapShotFinder);
      final snapshotButton =
          snapshotIconLabel.findAncestorWidgetOfExactType<OutlinedButton>()!;

      expect(snapshotButton.enabled, isFalse);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(
        controller.selectedSnapshotTimestamp!.millisecondsSinceEpoch,
        lessThan(DateTime.now().millisecondsSinceEpoch),
      );

      await expectLater(
        find.byType(MemoryVMChart),
        matchesDevToolsGolden('../goldens/memory_heap_tree.png'),
      );

      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Android Memory'), findsOneWidget);

      // Bring up the Android chart.
      await tester.tap(find.text('Android Memory'));
      await tester.pump();

      await tester.pumpAndSettle(const Duration(seconds: 2));

      await expectLater(
        find.byType(MemoryVMChart),
        matchesDevToolsGolden('../goldens/memory_heap_android.png'),
      );

      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // TODO(terry): Need to test legend.
      /*
      // Bring up the full legend with Android chart visible.
      expect(find.byKey(legendKey), findsOneWidget);
      // Bring up the legend.
      await tester.tap(find.byKey(legendKey));
      await tester.pump();

      await tester.pumpAndSettle(const Duration(seconds: 1));

      await expectLater(
        find.byKey(MemoryScreen.vmChartKey),
        matchesDevToolsGolden('../goldens/memory_heap_android_legend.png'),
      );

      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Hide the Android chart and make sure the legend recomputes.
      await tester.tap(find.byKey(MemoryScreen.androidChartButtonKey));
      await tester.pump();

      await tester.pumpAndSettle(const Duration(seconds: 1));

      await expectLater(
        find.byKey(MemoryScreen.vmChartKey),
        matchesDevToolsGolden('../goldens/memory_heap_legend.png'),
      );

      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));
      */
    });

    testWidgetsWithWindowSize(
      'allocation monitor, class tracking and search auto-complete',
      windowSize,
      (WidgetTester tester) async {
        const _oneSecond = Duration(seconds: 1);
        const _twoSeconds = Duration(seconds: 2);

        Future<void> pumpAndSettleOneSecond() async {
          await tester.pumpAndSettle(_oneSecond);
        }

        Future<void> pumpAndSettleTwoSeconds() async {
          await tester.pumpAndSettle(_twoSeconds);
        }

        await pumpMemoryScreen(tester);

        // Load canned data.
        _setUpServiceManagerForMemory();

        controller.refreshAllCharts();
        await pumpAndSettleTwoSeconds();

        expect(controller.offline.value, isTrue);

        Future<void> checkGolden(String goldenFilename, {Key? key}) async {
          // Await delay for golden comparison.
          await pumpAndSettleTwoSeconds();

          final finder =
              key == null ? find.byType(MemoryBody) : find.byKey(key);
          expect(finder, findsOneWidget);

          // Screenshot should display left-side tree table fully expanded and the monitor
          // allocation leaf node 'Monitor <timestamp>' selected. The right-side displaying
          // all allocations in a flat table, no items checked (tracked), search should
          // be enabled with focus. No tree table displayed on the bottom only empty message.
          await expectLater(finder, matchesDevToolsGolden(goldenFilename));
        }

        await pumpAndSettleTwoSeconds();

        await pumpMemoryScreen(tester);

        // Any exported memory files in the /tmp or $TMPDIR or /var/folders/Downloads will cause
        // the memory page's drop-down widget width to be wider than normal (longest exported file
        // name). For goldens don't generate snapshots as they we be slightly different on the bots.
        expect(
          controller.memoryLog.offlineFiles().isEmpty,
          isTrue,
          reason:
              '\n\n=========================================================================\n'
              'WARNING: Exported memory files in /tmp/memory_log_YYYYMMDD_HH_MM exist.\n'
              'The switch --update-goldens shouldn\'t be used until export files removed.\n'
              '=========================================================================',
        );

        expect(
          find.byKey(HeapTreeViewState.dartHeapAnalysisTabKey),
          findsOneWidget,
        );

        final allocationsKey =
            find.byKey(HeapTreeViewState.dartHeapAllocationsTabKey);
        await tester.tap(allocationsKey);

        await pumpAndSettleTwoSeconds();

        expect(find.text('Track'), findsOneWidget);
        expect(find.text('Reset'), findsOneWidget);

        await tester.tap(find.text('Track'));

        await pumpAndSettleTwoSeconds();

        final data = controller.monitorAllocations;

        // Total number of collected Allocations (ClassHeapDetailStats).
        expect(data.length, 31);

        ClassHeapDetailStats classDetails = data.first;
        expect(classDetails.classRef.name, 'AClass');
        expect(classDetails.classRef.id, 'classes/1');
        expect(classDetails.bytesCurrent, 10000);
        expect(classDetails.bytesDelta, 100);
        expect(classDetails.instancesCurrent, 10);
        expect(classDetails.instancesDelta, 10);
        //expect(classDetails.isStacktraced, isTrue);

        classDetails = data[9];
        expect(classDetails.classRef.name, 'JClass');
        expect(classDetails.classRef.id, 'classes/10');
        expect(classDetails.bytesCurrent, 100000);
        expect(classDetails.bytesDelta, 1000);
        expect(classDetails.instancesCurrent, 5);
        expect(classDetails.instancesDelta, 2);

        classDetails = data[19];
        expect(classDetails.classRef.name, 'TClass');
        expect(classDetails.classRef.id, 'classes/20');
        expect(classDetails.bytesCurrent, 10);
        expect(classDetails.bytesDelta, 0);
        expect(classDetails.instancesCurrent, 5);
        expect(classDetails.instancesDelta, 1);

        classDetails = data.last;
        expect(classDetails.classRef.name, 'LastClass');
        expect(classDetails.classRef.id, 'classes/30');
        expect(classDetails.bytesCurrent, 222);
        expect(classDetails.bytesDelta, 0);
        expect(classDetails.instancesCurrent, 55);
        expect(classDetails.instancesDelta, 0);

        // Use a consistent date/time for monitor timestamp so the goldens PNG match.
        useHardCodedMonitorTimestamp();

        // Screenshot should display left-side tree table fully expanded and the monitor
        // allocation leaf node 'Monitor <timestamp>' selected. The right-side displaying
        // all allocations in a flat table, no items checked (tracked), search should
        // be enabled with focus. No tree table displayed on the bottom only empty message.
        await checkGolden('../goldens/allocation_golden.png');

        // Enable classes to track.
        setupTracking(data);
        await pumpAndSettleOneSecond();

        // Validate the classes being tracked is accurate (should be classes tracked).
        expect(controller.trackAllocations, hasLength(classesToTrack.length));
        expect(
          controller.trackAllocations.values.join(','),
          classesToTrack.join(','),
        );

        // Use a consistent date/time for monitor timestamp so the goldens PNG match.
        useHardCodedMonitorTimestamp();

        // Screenshot should display left-side tree table fully expanded and the monitor
        // allocation leaf node 'Monitor <timestamp>' selected. The right-side displaying
        // all allocations in a flat table, with two items checked (tracked), search should
        // be enabled with focus. The tree table displayed on the bottom right-side below
        // the flat table should display 2 tracked classes.
        await checkGolden('../goldens/allocation_two_track_golden.png');

        // Turn off one class being tracked.
        expect(data[0].classRef.name, 'AClass');
        expect(data[0].isStacktraced, isTrue);
        controller.setTracking(data[0].classRef, false);
        await pumpAndSettleOneSecond();

        // Validate that track is off.
        expect(data[0].isStacktraced, isFalse);

        // Validate only one class is tracked now.
        expect(controller.trackAllocations.length, 1);
        expect(controller.trackAllocations.values.single, classesToTrack.last);

        // Use a consistent date/time for monitor timestamp so the goldens PNG match.
        useHardCodedMonitorTimestamp();

        // Screenshot should display left-side tree table fully expanded and the monitor
        // allocation leaf node 'Monitor <timestamp>' selected. The right-side displaying
        // all allocations in a flat table, with one class checked (tracked), search should
        // be enabled with focus. The tree table displayed on the bottom right-side below
        // the flat table should display one tracked class.
        await checkGolden('../goldens/allocation_one_track_golden.png');

        // Exercise search and auto-complete.
        final searchField = find.byKey(memorySearchFieldKey);
        await tester.tap(searchField);
        await pumpAndSettleOneSecond();

        final TextField textField = tester.widget(searchField) as TextField;
        expect(textField.enabled, isTrue);

        final textController = textField.controller!;
        expect(textController.text, isEmpty);
        expect(controller.searchAutoComplete.value, isEmpty);

        Future<void> _upDownArrow(
          int hilightedIndex, {
          downArrow = true,
        }) async {
          await simulateKeyDownEvent(
            downArrow
                ? LogicalKeyboardKey.arrowDown
                : LogicalKeyboardKey.arrowUp,
          );
          expect(controller.currentHoveredIndex.value, hilightedIndex);
        }

        Future<void> downArrow(int hilightedIndex) async {
          await _upDownArrow(hilightedIndex);
        }

        Future<void> upArrow(int hilightedIndex) async {
          await _upDownArrow(hilightedIndex, downArrow: false);
        }

        // Test for 10 items found in auto-complete
        const autoCompletes = [
          'AClass',
          'AnotherClass',
          'BClass',
          'CClass',
          'DClass',
          'EClass',
          'FClass',
          'GClass',
          'HClass',
          'IClass',
        ];
        final autoCompletesAsString = autoCompletes.join(',');

        await tester.enterText(searchField, 'A');
        await pumpAndSettleOneSecond();

        var autoCompletesDisplayed = controller.searchAutoComplete.value;
        expect(autoCompletesDisplayed, hasLength(autoCompletes.length));
        expect(autoCompletesDisplayed.join(','), autoCompletesAsString);

        // Check that up arrow circles around to bottom item in drop-down list.
        await upArrow(autoCompletes.indexOf('IClass'));
        expect(
          controller.currentHoveredIndex.value,
          autoCompletes.indexOf('IClass'),
        ); // IClass hilighted.
        await simulateKeyDownEvent(LogicalKeyboardKey.enter);

        var choosenAutoComplete = controller
            .allocationsFieldsTable!.activeSearchMatchNotifier!.value!;
        expect(choosenAutoComplete.classRef.name, 'IClass'); // IClass selected.

        // Test for 2 items found in auto-complete.
        final autoCompletes3 = ['AnotherClass', 'LastClass', 'TClass'];
        final autoCompletes3AsString = autoCompletes3.join(',');

        await tester.enterText(searchField, 't');
        autoCompletesDisplayed = controller.searchAutoComplete.value;
        expect(autoCompletesDisplayed, hasLength(autoCompletes3.length));
        expect(autoCompletesDisplayed.join(','), autoCompletes3AsString);
        await downArrow(
          autoCompletes3.indexOf('LastClass'),
        ); // TClass hilighted.

        await simulateKeyDownEvent(LogicalKeyboardKey.enter);
        choosenAutoComplete = controller
            .allocationsFieldsTable!.activeSearchMatchNotifier!.value!;
        expect(choosenAutoComplete.classRef.name, autoCompletes3[1]);

        // Test for 1 item found in auto-complete.
        await tester.enterText(searchField, 'Z');
        autoCompletesDisplayed = controller.searchAutoComplete.value;
        expect(autoCompletesDisplayed, hasLength(1));
        expect(autoCompletesDisplayed.single, 'ZClass');
        expect(controller.currentHoveredIndex.value, 0); // ZClass hilighted.
        await simulateKeyDownEvent(LogicalKeyboardKey.enter);

        choosenAutoComplete = controller
            .allocationsFieldsTable!.activeSearchMatchNotifier!.value!;
        expect(choosenAutoComplete.classRef.name, 'ZClass'); // ZClass selected.

        // Test for 4 items found in auto-complete.
        final autoCompletes5 = [
          'AnotherClass',
          'NClass',
          'OneClass',
          'OneMoreClass',
          'SecondClass',
        ];
        final autoCompletes4AsString = autoCompletes5.join(',');

        await tester.enterText(searchField, 'n');
        autoCompletesDisplayed = controller.searchAutoComplete.value;
        expect(autoCompletesDisplayed, hasLength(autoCompletes5.length));
        expect(autoCompletesDisplayed.join(','), autoCompletes4AsString);

        expect(
          controller.currentHoveredIndex.value,
          autoCompletes5.indexOf('AnotherClass'),
        ); // AnotherClass hilighted.

        // Cycle around hilighting each entry.

        // NClass hilighted.
        await downArrow(autoCompletes5.indexOf('NClass'));

        // Show's auto-complete dropdown with the 2nd item highlighted.
        await checkGolden(
          '../goldens/allocation_dropdown_hilight_line_2_golden.png',
          key: searchAutoCompleteKey,
        );

        // OneClass hilighted.
        await downArrow(autoCompletes5.indexOf('OneClass'));

        // Show's auto-complete dropdown with the 3rd item highlighted.
        await checkGolden(
          '../goldens/allocation_dropdown_hilight_line_3_golden.png',
          key: searchAutoCompleteKey,
        );

        // OneMoreClass hilighted.
        await downArrow(autoCompletes5.indexOf('OneMoreClass'));

        // SecondClass hilighted.
        await downArrow(autoCompletes5.indexOf('SecondClass'));

        // Show's auto-complete dropdown with the 4th item highlighted.
        await checkGolden(
          '../goldens/allocation_dropdown_hilight_line_4_golden.png',
          key: searchAutoCompleteKey,
        );

        // AnotherClass hilighted.
        await downArrow(autoCompletes5.indexOf('AnotherClass'));

        // Show's auto-complete dropdown with the last item highlighted.
        await checkGolden(
          '../goldens/allocation_dropdown_hilight_line_1_golden.png',
          key: searchAutoCompleteKey,
        );

        // NClass hilighted.
        await downArrow(autoCompletes5.indexOf('NClass'));

        // Show's auto-complete dropdown with the 2nd item highlighted.
        await checkGolden(
          '../goldens/allocation_dropdown_hilight_line_2_golden.png',
          key: searchAutoCompleteKey,
        );

        // Select last hilighted entry.
        await simulateKeyDownEvent(LogicalKeyboardKey.enter);

        choosenAutoComplete = controller
            .allocationsFieldsTable!.activeSearchMatchNotifier!.value!;
        // OneClass selected.
        expect(choosenAutoComplete.classRef.name, autoCompletes5[1]);
        // TODO(terry): MUST re-enable broken with latest eval auto-complete work.
        //              See https://github.com/flutter/devtools/issues/3030.
      },
      skip: true,
    );
  });
}
