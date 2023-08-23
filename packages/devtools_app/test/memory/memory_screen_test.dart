// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/chart_control_pane.dart';
import 'package:devtools_app/src/screens/memory/panes/chart/memory_vm_chart.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/test_data/memory.dart';
import '../test_infra/test_data/memory_allocation.dart';

void main() {
  late MemoryScreen screen;
  late MemoryController controller;
  late FakeServiceManager fakeServiceManager;

  // Load canned data testHeapSampleData.
  final memoryJson =
      SamplesMemoryJson.decode(argJsonString: testHeapSampleData);
  final allocationJson =
      AllocationMemoryJson.decode(argJsonString: testAllocationData);

  void setUpServiceManagerForMemory() {
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
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
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
    setUp(() {
      screen = MemoryScreen();
      controller = MemoryController();
      setUpServiceManagerForMemory();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Memory'), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'builds proper content for state',
      windowSize,
      (WidgetTester tester) async {
        await pumpMemoryScreen(tester);

        // Should be collecting live feed.
        expect(controller.offline, isFalse);

        // Verify Memory, Memory Source, and Memory Sources content.
        expect(find.byTooltip(ChartPaneTooltips.pauseTooltip), findsOneWidget);
        expect(find.byTooltip(ChartPaneTooltips.resumeTooltip), findsOneWidget);

        expect(find.text('GC'), findsOneWidget);

        expect(find.byType(MemoryVMChart), findsOneWidget);

        expect(controller.memoryTimeline.liveData.isEmpty, isTrue);
        expect(controller.memoryTimeline.offlineData.isEmpty, isTrue);
      },
    );
  });
}
