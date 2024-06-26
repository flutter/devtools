// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('visible_screens', () {
    late FakeServiceConnectionManager fakeServiceConnection;

    setUp(() async {
      fakeServiceConnection =
          FakeServiceConnectionManager(availableLibraries: []);
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(BreakpointManager, BreakpointManager());
      setGlobal(FrameworkController, FrameworkController());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(OfflineDataController, OfflineDataController());
      final scriptManager = MockScriptManager();
      when(scriptManager.sortedScripts).thenReturn(
        const FixedValueListenable<List<ScriptRef>>([]),
      );
      setGlobal(ScriptManager, scriptManager);

      await whenValueNonNull(
        serviceConnection.serviceManager.isolateManager.selectedIsolate,
      );
    });

    void setupMockValues({
      bool web = false,
      bool flutter = false,
      bool debugMode = true,
      SemanticVersion? flutterVersion,
    }) {
      if (web) {
        fakeServiceConnection.serviceManager.availableLibraries
            .add('dart:js_interop');
      }
      mockConnectedApp(
        fakeServiceConnection.serviceManager.connectedApp!,
        isFlutterApp: flutter,
        isProfileBuild: !debugMode,
        isWebApp: web,
      );
      if (flutter) {
        fakeServiceConnection.serviceManager.availableLibraries
            .add('package:flutter/src/widgets/binding.dart');
      }
      flutterVersion ??= SemanticVersion(major: 2, minor: 3, patch: 1);
      mockFlutterVersion(
        fakeServiceConnection.serviceManager.connectedApp!,
        flutterVersion,
      );
    }

    testWidgets('are correct for Dart CLI app', (WidgetTester tester) async {
      setupMockValues();

      expect(
        visibleScreenTypes,
        equals([
          HomeScreen,
          // InspectorScreen,
          // LegacyPerformanceScreen,
          PerformanceScreen,
          ProfilerScreen,
          MemoryScreen,
          DebuggerScreen,
          NetworkScreen,
          LoggingScreen,
          AppSizeScreen,
          DeepLinksScreen,
          // VMDeveloperToolsScreen,
        ]),
      );
    });

    testWidgets('are correct for Dart Web app', (WidgetTester tester) async {
      setupMockValues(web: true);

      expect(
        visibleScreenTypes,
        equals([
          HomeScreen,
          // InspectorScreen,
          // LegacyPerformanceScreen,
          PerformanceScreen,
          // ProfilerScreen,
          // MemoryScreen,
          DebuggerScreen,
          // NetworkScreen,
          LoggingScreen,
          // AppSizeScreen,
          // DeepLinksScreen,
          // VMDeveloperToolsScreen,
        ]),
      );
    });

    testWidgets(
      'are correct for Flutter (non-web) debug app',
      (WidgetTester tester) async {
        setupMockValues(flutter: true);

        expect(
          visibleScreenTypes,
          equals([
            HomeScreen,
            InspectorScreen,
            // LegacyPerformanceScreen,
            PerformanceScreen,
            ProfilerScreen,
            MemoryScreen,
            DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            AppSizeScreen,
            DeepLinksScreen,
            // VMDeveloperToolsScreen,
          ]),
        );
      },
    );

    testWidgets(
      'are correct for Flutter (non-web) profile app',
      (WidgetTester tester) async {
        setupMockValues(flutter: true, debugMode: false);

        expect(
          visibleScreenTypes,
          equals([
            HomeScreen,
            // InspectorScreen,
            // LegacyPerformanceScreen,
            PerformanceScreen,
            ProfilerScreen,
            MemoryScreen,
            // DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            AppSizeScreen,
            DeepLinksScreen,
            // VMDeveloperToolsScreen,
          ]),
        );
      },
    );

    testWidgets(
      'are correct for Flutter web debug app',
      (WidgetTester tester) async {
        setupMockValues(flutter: true, web: true);

        expect(
          visibleScreenTypes,
          equals([
            HomeScreen,
            InspectorScreen,
            // LegacyPerformanceScreen,
            PerformanceScreen,
            // ProfilerScreen,
            // MemoryScreen,
            DebuggerScreen,
            // NetworkScreen,
            LoggingScreen,
            // AppSizeScreen,
            // DeepLinksScreen,
            // VMDeveloperToolsScreen,
          ]),
        );
      },
    );

    testWidgets(
      'are correct for Flutter app on old Flutter version',
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
            HomeScreen,
            InspectorScreen,
            PerformanceScreen,
            ProfilerScreen,
            MemoryScreen,
            DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            AppSizeScreen,
            DeepLinksScreen,
            // VMDeveloperToolsScreen,
          ]),
        );
      },
    );

    testWidgets('are correct when offline', (WidgetTester tester) async {
      offlineDataController.startShowingOfflineData(
        offlineApp: serviceConnection.serviceManager.connectedApp!,
      );
      setupMockValues(web: true); // Web apps would normally hide

      expect(
        visibleScreenTypes,
        equals([
          // HomeScreen,
          // InspectorScreen,
          PerformanceScreen, // Works offline, so appears regardless of web flag
          ProfilerScreen, // Works offline, so appears regardless of web flag
          // MemoryScreen,
          // DebuggerScreen,
          // NetworkScreen,
          // LoggingScreen,
          // AppSizeScreen,
          // DeepLinksScreen,
          // VMDeveloperToolsScreen,
        ]),
      );
      offlineDataController.stopShowingOfflineData();
    });

    testWidgets(
      'are correct for Dart CLI app with VM developer mode enabled',
      (WidgetTester tester) async {
        preferences.toggleVmDeveloperMode(true);
        setupMockValues();
        expect(
          visibleScreenTypes,
          equals([
            HomeScreen,
            // InspectorScreen,
            // LegacyPerformanceScreen,
            PerformanceScreen,
            ProfilerScreen,
            MemoryScreen,
            DebuggerScreen,
            NetworkScreen,
            LoggingScreen,
            AppSizeScreen,
            DeepLinksScreen,
            VMDeveloperToolsScreen,
          ]),
        );
        preferences.toggleVmDeveloperMode(false);
      },
    );
  });
}

List<Type> get visibleScreenTypes => defaultScreens()
    .map((s) => s.screen)
    .where((s) => shouldShowScreen(s).show)
    .map((s) => s.runtimeType)
    .toList();
