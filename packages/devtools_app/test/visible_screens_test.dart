// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/app.dart';
import 'package:devtools_app/src/code_size/code_size_screen.dart';
import 'package:devtools_app/src/debugger/debugger_screen.dart';
import 'package:devtools_app/src/framework_controller.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/inspector_screen.dart';
import 'package:devtools_app/src/logging/logging_screen.dart';
import 'package:devtools_app/src/memory/memory_screen.dart';
import 'package:devtools_app/src/network/network_screen.dart';
import 'package:devtools_app/src/performance/performance_screen.dart';
import 'package:devtools_app/src/screen.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/timeline/timeline_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mocks.dart';

void main() {
  group('visible_screens', () {
    FakeServiceManager fakeServiceManager;

    setUp(() async {
      fakeServiceManager =
          FakeServiceManager(useFakeService: true, availableLibraries: []);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(FrameworkController, FrameworkController());

      await serviceManager.isolateManager.selectedIsolateAvailable.future;
    });

    void setupMockValues({
      bool web = false,
      bool flutter = false,
      bool debugMode = true,
    }) {
      mockIsDartVmApp(fakeServiceManager.connectedApp, !web);
      if (web) {
        fakeServiceManager.availableLibraries.add('dart:html');
      }
      mockIsFlutterApp(fakeServiceManager.connectedApp, flutter);
      if (flutter) {
        fakeServiceManager.availableLibraries
            .add('package:flutter/src/widgets/binding.dart');
      }
      mockIsDebugFlutterApp(
          fakeServiceManager.connectedApp, flutter && debugMode);
      mockIsProfileFlutterApp(
          fakeServiceManager.connectedApp, flutter && !debugMode);
    }

    testWidgets('are correct for Dart CLI app', (WidgetTester tester) async {
      setupMockValues();

      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            TimelineScreen,
            MemoryScreen,
            PerformanceScreen,
            DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            if (codeSizeScreenEnabled)
              CodeSizeScreen,
          ]));
    });

    testWidgets('are correct for Dart Web app', (WidgetTester tester) async {
      setupMockValues(web: true);

      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            // TimelineScreen,
            // MemoryScreen,
            // PerformanceScreen,
            DebuggerScreen,
            // NetworkScreen,
            LoggingScreen,
            // if (codeSizeScreenEnabled) CodeSizeScreen,
          ]));
    });

    testWidgets('are correct for Flutter (non-web) debug app',
        (WidgetTester tester) async {
      setupMockValues(flutter: true);

      expect(
          visibleScreenTypes,
          equals([
            InspectorScreen,
            TimelineScreen,
            MemoryScreen,
            PerformanceScreen,
            DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            if (codeSizeScreenEnabled) CodeSizeScreen,
          ]));
    });

    testWidgets('are correct for Flutter (non-web) profile app',
        (WidgetTester tester) async {
      setupMockValues(flutter: true, debugMode: false);

      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            TimelineScreen,
            MemoryScreen,
            PerformanceScreen,
            // DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            if (codeSizeScreenEnabled)
              CodeSizeScreen,
          ]));
    });

    testWidgets('are correct for Flutter web debug app',
        (WidgetTester tester) async {
      setupMockValues(flutter: true, web: true);

      expect(
          visibleScreenTypes,
          equals([
            InspectorScreen,
            // TimelineScreen,
            // MemoryScreen,
            // PerformanceScreen,
            DebuggerScreen,
            // NetworkScreen,
            LoggingScreen,
            // if (codeSizeScreenEnabled) CodeSizeScreen,
          ]));
    });

    testWidgets('are correct when offline', (WidgetTester tester) async {
      offlineMode = true;
      setupMockValues(web: true); // Web apps would normally hide

      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            TimelineScreen, // Works offline, so appears regardless of web flag
            // MemoryScreen,
            PerformanceScreen, // Works offline, so appears regardless of web flag
            // DebuggerScreen,
            // NetworkScreen,
            // LoggingScreen,
            // if (codeSizeScreenEnabled) CodeSizeScreen,
          ]));
    });
  });
}

List<Type> get visibleScreenTypes => defaultScreens
    .map((s) => s.screen)
    .where(shouldShowScreen)
    .map((s) => s.runtimeType)
    .toList();
