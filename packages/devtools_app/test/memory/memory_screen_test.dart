// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/memory/memory_controller.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/chart_control_pane.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/memory_events_pane.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/memory_vm_chart.dart';
import 'package:devtools_app/src/screens/memory/panes/control/source_dropdown.dart';
import 'package:devtools_app/src/screens/memory/shared/constants.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../matchers/matchers.dart';
import '../test_data/memory.dart';
import '../test_data/memory_allocation.dart';

void main() {
  late MemoryScreen screen;
  late MemoryController controller;
  late FakeServiceManager fakeServiceManager;

  // Load canned data testHeapSampleData.
  final memoryJson =
      SamplesMemoryJson.decode(argJsonString: testHeapSampleData);
  final allocationJson =
      AllocationMemoryJson.decode(argJsonString: testAllocationData);

  void _setUpServiceManagerForMemory() {
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
    setGlobal(PreferencesController, PreferencesController());
  }

  void initControllerState() {
    controller.offline.value = true;
    controller.memoryTimeline.offlineData.clear();
    controller.memoryTimeline.offlineData.addAll(memoryJson.data);
    controller.memoryTimeline.liveData.clear();
  }

  Future<void> pumpMemoryScreen(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const MemoryBody(),
        memory: controller,
      ),
    );

    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  group('MemoryScreen', () {
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
      setGlobal(NotificationService, NotificationService());
      screen = const MemoryScreen();
      controller = MemoryController();
      _setUpServiceManagerForMemory();
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
      expect(find.byTooltip(ChartPaneTooltips.pauseTooltip), findsOneWidget);
      expect(find.byTooltip(ChartPaneTooltips.resumeTooltip), findsOneWidget);

      expect(controller.memorySource, MemoryController.liveFeed);

      expect(find.text('GC'), findsOneWidget);

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
      await pumpMemoryScreen(tester);
      initControllerState();

      await tester.tap(find.text('Analysis'));
      await tester.pumpAndSettle();

      expect(controller.offline.value, isTrue);

      // Verify default event pane and vm chart exists.
      expect(find.byType(MemoryEventsPane), findsOneWidget);
      expect(find.byType(MemoryVMChart), findsOneWidget);

      expect(controller.memoryTimeline.liveData.isEmpty, isTrue);
      expect(controller.memoryTimeline.offlineData.isEmpty, isFalse);

      controller.refreshAllCharts();
      await tester.pumpAndSettle();

      expect(controller.memoryTimeline.data.isEmpty, isFalse);

      final data = controller.memoryTimeline.data;

      // Total number of collected HeapSamples.
      expect(data.length, 104);

      for (var _ in Iterable.generate(6)) {
        await tester.pumpAndSettle();
      }

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
        matchesDevToolsGolden('../test_infra/goldens/memory_hover_card.png'),
      );
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
      initControllerState();
      await tester.tap(find.text('Analysis'));
      await tester.pumpAndSettle();

      final heapSnapShotFinder = find.text('Take Heap Snapshot');

      expect(heapSnapShotFinder, findsOneWidget);

      expect(controller.offline.value, isTrue);

      // Verify default event pane and vm chart exists.
      expect(find.byType(MemoryEventsPane), findsOneWidget);
      expect(find.byType(MemoryVMChart), findsOneWidget);

      expect(controller.memoryTimeline.liveData.isEmpty, isTrue);
      expect(controller.memoryTimeline.offlineData.isNotEmpty, isTrue);

      controller.refreshAllCharts();
      expect(controller.isAndroidChartVisibleNotifier.value, true);

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

      await tester.pumpAndSettle(const Duration(seconds: 2));

      await expectLater(
        find.byType(MemoryVMChart),
        matchesDevToolsGolden('../test_infra/goldens/memory_heap_android.png'),
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
        matchesDevToolsGolden('../test_infra/goldens/memory_heap_android_legend.png'),
      );

      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Hide the Android chart and make sure the legend recomputes.
      await tester.tap(find.byKey(MemoryScreen.androidChartButtonKey));
      await tester.pump();

      await tester.pumpAndSettle(const Duration(seconds: 1));

      await expectLater(
        find.byKey(MemoryScreen.vmChartKey),
        matchesDevToolsGolden('../test_infra/goldens/memory_heap_legend.png'),
      );

      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));
      */
    });
  });
}
