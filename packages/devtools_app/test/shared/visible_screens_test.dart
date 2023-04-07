// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('visible_screens', () {
    late FakeServiceManager fakeServiceManager;

    setUp(() async {
      fakeServiceManager = FakeServiceManager(availableLibraries: []);
      setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      setGlobal(BreakpointManager, BreakpointManager());
      setGlobal(FrameworkController, FrameworkController());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(OfflineModeController, OfflineModeController());
      final scriptManager = MockScriptManager();
      when(scriptManager.sortedScripts).thenReturn(
        const FixedValueListenable<List<ScriptRef>>([]),
      );
      setGlobal(ScriptManager, scriptManager);

      await whenValueNonNull(serviceManager.isolateManager.selectedIsolate);
    });

    void setupMockValues({
      bool web = false,
      bool flutter = false,
      bool debugMode = true,
      SemanticVersion? flutterVersion,
    }) {
      if (web) {
        fakeServiceManager.availableLibraries.add('dart:html');
      }
      mockConnectedApp(
        fakeServiceManager.connectedApp!,
        isFlutterApp: flutter,
        isProfileBuild: !debugMode,
        isWebApp: web,
      );
      if (flutter) {
        fakeServiceManager.availableLibraries
            .add('package:flutter/src/widgets/binding.dart');
      }
      flutterVersion ??= SemanticVersion(major: 2, minor: 3, patch: 1);
      mockFlutterVersion(
        fakeServiceManager.connectedApp!,
        flutterVersion,
      );
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
        ]),
      );
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
        ]),
      );
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
        ]),
      );
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
        ]),
      );
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
        ]),
      );
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
        ]),
      );
    });

    testWidgets('are correct when offline', (WidgetTester tester) async {
      offlineController.enterOfflineMode(
        offlineApp: serviceManager.connectedApp!,
      );
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
        ]),
      );
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
        ]),
      );
      preferences.toggleVmDeveloperMode(false);
    });
  });
}

List<Type> get visibleScreenTypes => defaultScreens
    .map((s) => s.screen)
    .where(shouldShowScreen)
    .map((s) => s.runtimeType)
    .toList();
