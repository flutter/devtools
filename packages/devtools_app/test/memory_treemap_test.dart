// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/memory/memory_controller.dart';
import 'package:devtools_app/src/memory/memory_heap_tree_view.dart';
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

  group('MemoryTreemap', () {
    const windowSize = Size(2225.0, 1000.0);

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

    testWidgetsWithWindowSize('builds proper content for state', windowSize,
        (WidgetTester tester) async {
      await pumpMemoryScreen(tester);

     expect(find.byKey(HeapTreeViewState.snapshotButtonKey), findsOneWidget);
     expect(find.byKey(HeapTreeViewState.snapshotButtonKey), findsOneWidget);

    });


  });
}
