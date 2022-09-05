// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/memory_events_pane.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/memory_vm_chart.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../../matchers/matchers.dart';
import '../../test_data/memory.dart';
import '../../test_data/memory_allocation.dart';

void main() {
  late MemoryController controller;
  late FakeServiceManager fakeServiceManager;

  /// Classes to track while testing.
  final classesToTrack = <ClassRef>[];

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
      setGlobal(
        PreferencesController,
        PreferencesController()..memory.androidCollectionEnabled.value = true,
      );
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

      // expect(find.text('Android Memory'), findsOneWidget);
      //
      // // Bring up the Android chart.
      // await tester.tap(find.text('Android Memory'));
      // await tester.pump();
      //
      // await tester.pumpAndSettle(const Duration(seconds: 2));

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
  });
}
