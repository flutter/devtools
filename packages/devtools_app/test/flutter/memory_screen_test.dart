// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')

import 'package:devtools_app/src/flutter/split.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/memory/flutter/memory_chart.dart';
import 'package:devtools_app/src/memory/flutter/memory_screen.dart';
import 'package:devtools_app/src/memory/memory_controller.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

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
      memoryController: controller = memoryController ?? MemoryController(),
    ));
    expect(find.byType(MemoryBody), findsOneWidget);
  }

  const windowSize = Size(1599.0, 1000.0);

  group('MemoryScreen', () {
    setUp(() async {
      await ensureInspectorDependencies();
      fakeServiceManager = FakeServiceManager(useFakeService: true);
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

      var splitFinder = find.byType(Split);

      // Verify Memory, Memory Source, and Memory Sources content.
      expect(splitFinder, findsOneWidget);
      expect(find.byKey(MemoryScreen.pauseButtonKey), findsOneWidget);
      expect(find.byKey(MemoryScreen.resumeButtonKey), findsOneWidget);

      expect(find.byKey(MemoryScreen.memorySourceStatusKey), findsOneWidget);
      final Text memorySourceText = tester.firstWidget(find.byKey(
        MemoryScreen.memorySourceStatusKey,
      )) as Text;
      expect(memorySourceText.data, MemoryBodyState.liveFeed);

      expect(find.byKey(MemoryScreen.snapshotButtonKey), findsOneWidget);
      expect(find.byKey(MemoryScreen.resetButtonKey), findsOneWidget);
      expect(find.byKey(MemoryScreen.gcButtonKey), findsOneWidget);

      expect(find.byType(MemoryChart), findsOneWidget);

      expect(controller.memoryTimeline.data.isEmpty, isTrue);
      expect(controller.memoryTimeline.offflineData.isEmpty, isTrue);

      // Verify the state of the splitter.
      splitFinder = find.byType(Split);
      expect(splitFinder, findsOneWidget);
      final Split splitter = tester.widget(splitFinder);
      expect(splitter.initialFirstFraction, equals(0.25));

      // Check memory sources available.
      await tester.tap(find.byKey(MemoryScreen.popupSourceMenuButtonKey));
      await tester.pump();

      // Should only be one source 'Live Feed' in the popup menu.
      final Text memorySources = tester.firstWidget(find.byKey(
        MemoryScreen.memorySourcesKey,
      )) as Text;
      expect(memorySources.data, MemoryBodyState.liveFeed);
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
      expect(controller.memoryTimeline.data.isEmpty, isTrue);
      expect(controller.memoryTimeline.offflineData.isEmpty, isTrue);

      final currentMemoryLogs = controller.memoryLog.offlineFiles();
      expect(previousMemoryLogs.length + 1 == currentMemoryLogs.length, isTrue);
    });

    testWidgetsWithWindowSize('load memory log profile', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

      // Verify initial state - collecting live feed.
      expect(controller.offline, isFalse);

      // Export memory to a memory log file.
      await tester.tap(find.byKey(MemoryScreen.popupSourceMenuButtonKey));
      await tester.pump();

      // TODO(terry): Load canned test data.
      final filenames = controller.memoryLog.offlineFiles();
      controller.memoryLog.loadOffline(filenames[0]);

      expect(controller.offline, isTrue);
    });
  });
}
