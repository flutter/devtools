// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/app.dart';
import 'package:devtools_app/src/app_size/app_size_screen.dart';
import 'package:devtools_app/src/debugger/debugger_screen.dart';
import 'package:devtools_app/src/framework_controller.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/inspector_screen.dart';
import 'package:devtools_app/src/logging/logging_screen.dart';
import 'package:devtools_app/src/memory/memory_screen.dart';
import 'package:devtools_app/src/network/network_screen.dart';
import 'package:devtools_app/src/performance/legacy/performance_screen.dart';
import 'package:devtools_app/src/performance/performance_screen.dart';
import 'package:devtools_app/src/preferences.dart';
import 'package:devtools_app/src/profiler/profiler_screen.dart';
import 'package:devtools_app/src/screen.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:devtools_app/src/version.dart';
import 'package:devtools_app/src/vm_developer/vm_developer_tools_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mocks.dart';

void main() {
  group('visible_screens', () {
    FakeServiceManager fakeServiceManager;

    setUp(() async {
      fakeServiceManager = FakeServiceManager(availableLibraries: []);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(FrameworkController, FrameworkController());
      setGlobal(PreferencesController, PreferencesController());

      await whenValueNonNull(serviceManager.isolateManager.selectedIsolate);
    });

    void setupMockValues({
      bool web = false,
      bool flutter = false,
      bool debugMode = true,
      SemanticVersion flutterVersion,
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
        fakeServiceManager.connectedApp,
        flutter && debugMode,
      );
      mockIsProfileFlutterApp(
        fakeServiceManager.connectedApp,
        flutter && !debugMode,
      );
      flutterVersion ??= SemanticVersion(major: 2, minor: 3, patch: 1);
      mockFlutterVersion(fakeServiceManager.connectedApp, flutterVersion);
    }

    testWidgets('are correct for Dart CLI app', (WidgetTester tester) async {
      setupMockValues();

      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            // LegacyPerformanceScreen,
            PerformanceScreen,
            ProfilerScreen,
            MemoryScreen,
            DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            AppSizeScreen,
            // VMDeveloperToolsScreen,
          ]));
    });

    testWidgets('are correct for Dart Web app', (WidgetTester tester) async {
      setupMockValues(web: true);

      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            // LegacyPerformanceScreen,
            // PerformanceScreen,
            // ProfilerScreen,
            // MemoryScreen,
            DebuggerScreen,
            // NetworkScreen,
            LoggingScreen,
            // AppSizeScreen,
            // VMDeveloperToolsScreen,
          ]));
    });

    testWidgets('are correct for Flutter (non-web) debug app',
        (WidgetTester tester) async {
      setupMockValues(flutter: true);

      expect(
          visibleScreenTypes,
          equals([
            InspectorScreen,
            // LegacyPerformanceScreen,
            PerformanceScreen,
            ProfilerScreen,
            MemoryScreen,
            DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            AppSizeScreen,
            // VMDeveloperToolsScreen,
          ]));
    });

    testWidgets('are correct for Flutter (non-web) profile app',
        (WidgetTester tester) async {
      setupMockValues(flutter: true, debugMode: false);

      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            // LegacyPerformanceScreen,
            PerformanceScreen,
            ProfilerScreen,
            MemoryScreen,
            // DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            AppSizeScreen,
            // VMDeveloperToolsScreen,
          ]));
    });

    testWidgets('are correct for Flutter web debug app',
        (WidgetTester tester) async {
      setupMockValues(flutter: true, web: true);

      expect(
          visibleScreenTypes,
          equals([
            InspectorScreen,
            // LegacyPerformanceScreen,
            // PerformanceScreen,
            // ProfilerScreen,
            // MemoryScreen,
            DebuggerScreen,
            // NetworkScreen,
            LoggingScreen,
            // AppSizeScreen,
            // VMDeveloperToolsScreen,
          ]));
    });

    testWidgets('are correct for Flutter app on old Flutter version',
        (WidgetTester tester) async {
      setupMockValues(
        flutter: true,
        flutterVersion: SemanticVersion(major: 2, minor: 3),
      );

      expect(
          visibleScreenTypes,
          equals([
            InspectorScreen,
            LegacyPerformanceScreen,
            // PerformanceScreen,
            ProfilerScreen,
            MemoryScreen,
            DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            AppSizeScreen,
            // VMDeveloperToolsScreen,
          ]));
    });

    testWidgets('are correct when offline', (WidgetTester tester) async {
      offlineMode = true;
      setupMockValues(web: true); // Web apps would normally hide

      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            LegacyPerformanceScreen, // Works offline, so appears regardless of web flag
            PerformanceScreen, // Works offline, so appears regardless of web flag
            ProfilerScreen, // Works offline, so appears regardless of web flag
            // MemoryScreen,
            // DebuggerScreen,
            // NetworkScreen,
            // LoggingScreen,
            // AppSizeScreen,
            // VMDeveloperToolsScreen,
          ]));
      offlineMode = false;
    });

    testWidgets('are correct for Dart CLI app with VM developer mode enabled',
        (WidgetTester tester) async {
      preferences.toggleVmDeveloperMode(true);
      setupMockValues();
      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            // LegacyPerformanceScreen,
            PerformanceScreen,
            ProfilerScreen,
            MemoryScreen,
            DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            AppSizeScreen,
            VMDeveloperToolsScreen,
          ]));
      preferences.toggleVmDeveloperMode(false);
    });
  });
}

List<Type> get visibleScreenTypes => defaultScreens
    .map((s) => s.screen)
    .where(shouldShowScreen)
    .map((s) => s.runtimeType)
    .toList();
