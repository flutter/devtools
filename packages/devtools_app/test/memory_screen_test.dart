// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/memory/memory_chart.dart';
import 'package:devtools_app/src/memory/memory_controller.dart';
import 'package:devtools_app/src/memory/memory_screen.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  MemoryScreen screen;
  MemoryController controller;
  FakeServiceManager fakeServiceManager;

  Future<void> pumpMemoryScreen(
    WidgetTester tester, {
    MemoryController memoryController,
  }) async {
    // Set a wide enough screen width that we do not run into overflow.
    await tester.pumpWidget(wrapWithControllers(
      const MemoryBody(),
      memory: controller = memoryController ?? MemoryController(),
    ));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  const windowSize = Size(2225.0, 1000.0);

  group('MemoryScreen', () {
    setUp(() async {
      await ensureInspectorDependencies();
      fakeServiceManager = FakeServiceManager(useFakeService: true);
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

//      expect(find.byKey(MemoryScreen.snapshotButtonKey), findsOneWidget);
//      expect(find.byKey(MemoryScreen.resetButtonKey), findsOneWidget);
      expect(find.byKey(MemoryScreen.gcButtonKey), findsOneWidget);

      expect(find.byType(MemoryChart), findsOneWidget);

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

      // TODO(terry): Load canned test data.
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
}
