// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/framework/memory_tabs.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/widgets/chart_control_pane.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/widgets/chart_pane.dart';
import 'package:devtools_app/src/screens/memory/panes/profile/profile_view.dart';
import 'package:devtools_app/src/screens/memory/panes/tracing/tracing_view.dart';
import 'package:devtools_app/src/screens/memory/shared/widgets/shared_memory_widgets.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../test_infra/matchers/matchers.dart';
import '../../../test_infra/test_data/memory.dart';
import '../../../test_infra/test_data/memory/offline/memory_offline_data.dart'
    as memory_offline;
import '../../../test_infra/test_data/memory_allocation.dart';

void main() {
  late MemoryController controller;
  late FakeServiceConnectionManager fakeServiceConnection;

  // Load canned data testHeapSampleData.
  final memoryJson = SamplesMemoryJson.decode(
    argJsonString: testHeapSampleData,
  );
  final allocationJson = AllocationMemoryJson.decode(
    argJsonString: testAllocationData,
  );

  void setUpServiceManagerForMemory() {
    fakeServiceConnection = FakeServiceConnectionManager(
      service: FakeServiceManager.createFakeService(
        memoryData: memoryJson,
        allocationData: allocationJson,
      ),
    );
    when(
      fakeServiceConnection.serviceManager.connectedApp!.isDartWebAppNow,
    ).thenReturn(false);
    when(
      fakeServiceConnection.serviceManager.connectedApp!.isFlutterAppNow,
    ).thenReturn(true);
    when(
      fakeServiceConnection.serviceManager.connectedApp!.isDartCliAppNow,
    ).thenReturn(false);
    when(
      fakeServiceConnection.serviceManager.connectedApp!.isDebugFlutterAppNow,
    ).thenReturn(false);
    when(
      fakeServiceConnection.serviceManager.connectedApp!.isDartWebApp,
    ).thenAnswer((_) => Future.value(false));
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
  }

  Future<void> pumpMemoryScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(const MemoryScreenBody(), memory: controller),
    );

    // Delay to ensure the memory profiler has collected data.
    await tester.runAsync(
      () async => await tester.pumpAndSettle(const Duration(seconds: 2)),
    );
    expect(find.byType(MemoryScreenBody), findsOneWidget);
  }

  // Set a wide enough screen width that we do not run into overflow.
  const windowSize = Size(2225.0, 1000.0);

  group('MemoryScreen', () {
    setUp(() {
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(OfflineDataController, OfflineDataController());
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(NotificationService, NotificationService());
      setGlobal(BannerMessagesController, BannerMessagesController());
      setGlobal(DTDManager, MockDTDManager());
      setGlobal(ScriptManager, MockScriptManager());
      setUpServiceManagerForMemory();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: MemoryScreen().buildTab)));
      expect(find.text('Memory'), findsOneWidget);
    });

    group('with connected app', () {
      setUp(() async {
        controller = MemoryController();
        await controller.initialized;
      });

      testWidgetsWithWindowSize('builds proper content for state', windowSize, (
        WidgetTester tester,
      ) async {
        await pumpMemoryScreen(tester);

        // Verify chart is visible.
        expect(find.byTooltip(ChartPaneTooltips.pauseTooltip), findsOneWidget);
        expect(find.byTooltip(ChartPaneTooltips.resumeTooltip), findsOneWidget);

        expect(find.text('GC'), findsOneWidget);

        expect(find.byType(MemoryChartPane), findsOneWidget);
      });
    });

    group('with offline data', () {
      setUp(() async {
        offlineDataController
          ..offlineDataJson = memory_offline.data
          ..startShowingOfflineData(
            offlineApp: serviceConnection.serviceManager.connectedApp!,
          );

        controller = MemoryController();
        await controller.initialized;
      });

      testWidgetsWithWindowSize('loads successfully', windowSize, (
        WidgetTester tester,
      ) async {
        await pumpMemoryScreen(tester);

        // Initial load on the profile tab.
        expect(find.byType(AllocationProfileTableView), findsOneWidget);
        expect(find.byType(HeapClassView), findsNWidgets(3));
        await expectLater(
          find.byType(MemoryScreenBody),
          matchesDevToolsGolden(
            '../../../test_infra/goldens/memory/load_offline_data_profile_tab.png',
          ),
        );

        // TODO(kenz): investigate why pump and settle times out when
        // switching to the diff tab. This works when loading offline data
        // locally, so it is something related to running async code in the
        // test environment.
        // Switch to the diff tab.
        // await tester.runAsync(() async {
        //   await tester.tap(find.byKey(MemoryScreenKeys.diffTab));
        //   await tester.pumpAndSettle();
        // });
        // await expectLater(
        //   find.byType(MemoryScreenBody),
        //   matchesDevToolsGolden(
        //     '../../../test_infra/goldens/memory/load_offline_data_diff_tab.png',
        //   ),
        // );
        // Select a snapshot.
        // await tester.runAsync(() async {
        //   expect(find.byType(SnapshotListTitle), findsNWidgets(3));
        //   await tester.tap(find.byType(SnapshotListTitle).last);
        //   await tester.pumpAndSettle();
        // });
        // await expectLater(
        //   find.byType(MemoryScreenBody),
        //   matchesDevToolsGolden(
        //     '../../../test_infra/goldens/memory/load_offline_data_diff_tab_snapshot_selected.png',
        //   ),
        // );

        // Switch to the trace tab.
        await tester.runAsync(() async {
          await tester.tap(find.byKey(MemoryScreenKeys.traceTab));
          await tester.pumpAndSettle();
          await controller.trace!.initialized;
          await tester.pumpAndSettle();

          // TODO(kenz): remove this selection when the selected class is
          // included with the offline data for the Trace tab.
          // Select the first class in the trace tab.
          await tester.tap(find.byType(HeapClassView).first);
          await tester.pumpAndSettle();

          // Expand the selected allocation trace.
          await tester.tap(find.byType(ExpandAllButton));
          await tester.pumpAndSettle();
        });
        expect(find.byType(TracingPane), findsOneWidget);
        await expectLater(
          find.byType(MemoryScreenBody),
          matchesDevToolsGolden(
            '../../../test_infra/goldens/memory/load_offline_data_trace_tab.png',
          ),
        );
      });
    });
  });
}
