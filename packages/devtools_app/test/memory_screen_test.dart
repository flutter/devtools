// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/memory/memory_controller.dart';
import 'package:devtools_app/src/memory/memory_heap_tree_view.dart';
import 'package:devtools_app/src/memory/memory_screen.dart';
import 'package:devtools_app/src/memory/memory_vm_chart.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_testing/support/memory_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  MemoryScreen screen;
  MemoryController controller;
  FakeServiceManager fakeServiceManager;

  void _setUpServiceManagerForMemory() {
    // Load canned data testHeapSampleData.
    final memoryJson = MemoryJson.decode(argJsonString: testHeapSampleData);
    fakeServiceManager = FakeServiceManager(
      service: FakeServiceManager.createFakeService(memoryData: memoryJson),
    );
    when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
    when(fakeServiceManager.connectedApp.isDartCliAppNow).thenReturn(false);
    when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
        .thenReturn(false);
    when(fakeServiceManager.connectedApp.isDartWebApp)
        .thenAnswer((_) => Future.value(false));
    setGlobal(ServiceConnectionManager, fakeServiceManager);

    controller.offline = true;
    controller.memoryTimeline.offlineData.clear();
    controller.memoryTimeline.offlineData.addAll(memoryJson.data);
  }

  Future<void> pumpMemoryScreen(
    WidgetTester tester, {
    MemoryController memoryController,
  }) async {
    // Set a wide enough screen width that we do not run into overflow.
    await tester.pumpWidget(wrapWithControllers(
      const MemoryBody(),
      memory: controller = memoryController ?? MemoryController(),
    ));

    // Delay to ensure the memory profiler has collected data.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  const windowSize = Size(2225.0, 1000.0);

  group('MemoryScreen', () {
    setUp(() async {
      await ensureInspectorDependencies();
      fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      when(fakeServiceManager.connectedApp.isDebugFlutterAppNow)
          .thenReturn(false);
      when(fakeServiceManager.vm.operatingSystem).thenReturn('iOS');
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      screen = const MemoryScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Memory'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds proper content for state', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      // Should be collecting live feed.
      expect(controller.offline, isFalse);

      // Verify Memory, Memory Source, and Memory Sources content.
      expect(find.byKey(MemoryScreen.pauseButtonKey), findsOneWidget);
      expect(find.byKey(MemoryScreen.resumeButtonKey), findsOneWidget);

      expect(controller.memorySource, MemoryController.liveFeed);

      expect(find.byKey(MemoryScreen.gcButtonKey), findsOneWidget);

      expect(find.byType(MemoryVMChart), findsOneWidget);

      expect(controller.memoryTimeline.liveData.isEmpty, isTrue);
      expect(controller.memoryTimeline.offlineData.isEmpty, isTrue);

      // Check memory sources available.
      await tester.tap(find.byKey(MemoryScreen.dropdownSourceMenuButtonKey));
      await tester.pump();

      // Should only be one source 'Live Feed' in the popup menu.
      final memorySources = tester.firstWidget(find.byKey(
        MemoryScreen.memorySourcesKey,
      )) as Text;

      expect(
        memorySources.data,
        '${controller.memorySourcePrefix}${MemoryController.liveFeed}',
      );
    });

    testWidgetsWithWindowSize('export current memory profile', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      // Verify initial state - collecting live feed.
      expect(controller.offline, isFalse);

      final previousMemoryLogs = controller.memoryLog.offlineFiles();

      // Export memory to a memory log file.
      await tester.tap(find.byKey(MemoryScreen.exportButtonKey));
      await tester.pump();

      expect(controller.offline, isFalse);

      expect(controller.memoryTimeline.liveData, isEmpty);
      expect(controller.memoryTimeline.offlineData, isEmpty);

      final currentMemoryLogs = controller.memoryLog.offlineFiles();
      expect(currentMemoryLogs.length, previousMemoryLogs.length + 1);

      // Verify that memory source is still live feed.
      expect(controller.offline, isFalse);
    });

    testWidgetsWithWindowSize('export current memory profile', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      // Live feed should be default selected.
      expect(controller.memorySource, MemoryController.liveFeed);

      // Export memory to a memory log file.
      await tester.tap(find.byKey(MemoryScreen.dropdownSourceMenuButtonKey));
      await tester.pump();

      // Last item in dropdown list of memory source should be memory log file.
      await tester.tap(find.byKey(MemoryScreen.memorySourcesMenuItem).last);
      await tester.pump();

      expect(
        controller.memorySource,
        startsWith(MemoryController.logFilenamePrefix),
      );

      final filenames = controller.memoryLog.offlineFiles();
      final filename = filenames.first;

      expect(filename, startsWith(MemoryController.logFilenamePrefix));

      controller.memoryLog.loadOffline(filename);

      expect(controller.offline, isTrue);

      // Remove the memory log, in desktop only version.  Don't want to polute
      // our temp directory when this test runs locally.
      expect(controller.memoryLog.removeOfflineFile(filename), isTrue);
    });
  });

  testWidgetsWithWindowSize('heap tree view', windowSize,
      (WidgetTester tester) async {
    await pumpMemoryScreen(tester);

    expect(find.byKey(HeapTreeViewState.snapshotButtonKey), findsOneWidget);
    expect(
      find.byKey(HeapTreeViewState.allocationMonitorResetKey),
      findsOneWidget,
    );
    expect(
      find.byKey(HeapTreeViewState.allocationMonitorResetKey),
      findsOneWidget,
    );

    // Load canned data.
    _setUpServiceManagerForMemory();

    final data = controller.memoryTimeline.data;

    // Total number of collected HeapSamples.
    expect(data.length, 292);

    // Number of VM GCs
    final totalGCEvents = data.where((element) => element.isGC);
    expect(totalGCEvents.length, 70);

    // User initiated GCs
    final totalUserGCEvents =
        data.where((element) => element.memoryEventInfo.isEventGC);
    expect(totalUserGCEvents.length, 2);

    // User initiated Snapshots
    final totalSnapshotEvents =
        data.where((element) => element.memoryEventInfo.isEventSnapshot);
    expect(totalSnapshotEvents.length, 2);

    // Number of auto-Snapshots
    final totalSnapshotAutoEvents =
        data.where((element) => element.memoryEventInfo.isEventSnapshotAuto);
    expect(totalSnapshotAutoEvents.length, 3);

    // Total Allocation Monitor events (many are empty).
    final totalAllocationMonitorEvents = data.where(
        (element) => element.memoryEventInfo.isEventAllocationAccumulator);
    expect(totalAllocationMonitorEvents.length, 285);

    // Number of user initiated allocation monitors
    final startMonitors = totalAllocationMonitorEvents.where(
        (element) => element.memoryEventInfo.allocationAccumulator.isStart);
    expect(startMonitors.length, 3);

    // Number of accumulator resets
    final resetMonitors = totalAllocationMonitorEvents.where(
        (element) => element.memoryEventInfo.allocationAccumulator.isReset);
    expect(resetMonitors.length, 2);

    final interval1Min = MemoryController.displayIntervalToIntervalDurationInMs(
      ChartInterval.OneMinute,
    );
    expect(interval1Min, 60000);
    final interval5Min = MemoryController.displayIntervalToIntervalDurationInMs(
      ChartInterval.FiveMinutes,
    );
    expect(interval5Min, 300000);

    // TODO(terry): Check intervals and autosnapshot does it snapshot same points?
    // TODO(terry): Simulate sample run of liveData filling up?

    // Take a snapshot
    await tester.tap(find.byKey(HeapTreeViewState.snapshotButtonKey));
    await tester.pump();

    final snapshotButton = tester
        .widget<OutlineButton>(find.byKey(HeapTreeViewState.snapshotButtonKey));

    expect(snapshotButton.enabled, isFalse);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(
      controller.selectedSnapshotTimestamp.millisecondsSinceEpoch,
      lessThan(DateTime.now().millisecondsSinceEpoch),
    );
  });
}
