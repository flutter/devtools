// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:devtools_app/src/app.dart';
import 'package:devtools_app/src/screens/app_size/app_size_screen.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/screens/inspector/inspector_screen.dart';
import 'package:devtools_app/src/screens/logging/logging_screen.dart';
import 'package:devtools_app/src/screens/memory/memory_screen.dart';
import 'package:devtools_app/src/screens/network/network_screen.dart';
import 'package:devtools_app/src/screens/performance/performance_screen.dart';
import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/screens/profiler/profiler_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/preferences.dart';
import 'package:devtools_app/src/shared/screen.dart';
import 'package:devtools_app/src/shared/version.dart';
import 'package:devtools_app/src/vm_developer/vm_developer_tools_screen.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('visible_screens', () {
    FakeServiceManager fakeServiceManager;

    setUp(() async {
      fakeServiceManager = FakeServiceManager(availableLibraries: []);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(FrameworkController, FrameworkController());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(OfflineModeController, OfflineModeController());

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
      mockIsFlutterApp(
        fakeServiceManager.connectedApp,
        isFlutterApp: flutter,
        isProfileBuild: !debugMode,
      );
      if (flutter) {
        fakeServiceManager.availableLibraries
            .add('package:flutter/src/widgets/binding.dart');
      }
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
        flutterVersion: SemanticVersion(
          major: 2,
          minor: 3,
          // Specifying patch makes the version number more readable.
          // ignore: avoid_redundant_argument_values
          patch: 0,
          preReleaseMajor: 15,
          preReleaseMinor: 0,
        ),
      );

      expect(
          visibleScreenTypes,
          equals([
            InspectorScreen,
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

    testWidgets('are correct when offline', (WidgetTester tester) async {
      offlineController.enterOfflineMode();
      setupMockValues(web: true); // Web apps would normally hide

      expect(
          visibleScreenTypes,
          equals([
            // InspectorScreen,
            PerformanceScreen, // Works offline, so appears regardless of web flag
            ProfilerScreen, // Works offline, so appears regardless of web flag
            // MemoryScreen,
            // DebuggerScreen,
            // NetworkScreen,
            // LoggingScreen,
            // AppSizeScreen,
            // VMDeveloperToolsScreen,
          ]));
      offlineController.exitOfflineMode();
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
