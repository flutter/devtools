// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  const windowSize = Size(4000.0, 4000.0);
  late FakeServiceConnectionManager fakeServiceConnection;
  late MockDebuggerController debuggerController;
  late MockCodeViewController codeViewController;
  late ScriptsHistory scriptsHistory;
  late ValueNotifier<bool> showCodeCoverage;
  late ValueNotifier<bool> showProfileHits;
  bool refreshCodeCoverageInvoked = false;

  setUpAll(() {
    setGlobal(BreakpointManager, BreakpointManager());
    fakeServiceConnection = FakeServiceConnectionManager();
    codeViewController = createMockCodeViewControllerWithDefaults();
    debuggerController = createMockDebuggerControllerWithDefaults(
      codeViewController: codeViewController,
    );
    scriptsHistory = ScriptsHistory();

    final app = fakeServiceConnection.serviceManager.connectedApp!;
    mockConnectedApp(
      app,
      isFlutterApp: false,
      isProfileBuild: false,
      isWebApp: false,
    );
    when(fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow)
        .thenReturn(false);
    when(fakeServiceConnection.serviceManager.connectedApp!.isDartWebAppNow)
        .thenReturn(false);
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, MockScriptManager());
    setGlobal(NotificationService, NotificationService());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    scriptsHistory.pushEntry(mockScript!);
    final mockCodeViewController = debuggerController.codeViewController;

    when(mockCodeViewController.currentScriptRef)
        .thenReturn(ValueNotifier(mockScriptRef));
    when(mockCodeViewController.currentParsedScript)
        .thenReturn(ValueNotifier(mockParsedScript));
    when(mockCodeViewController.scriptsHistory).thenReturn(scriptsHistory);

    showCodeCoverage = ValueNotifier<bool>(false);
    showProfileHits = ValueNotifier<bool>(false);
    when(mockCodeViewController.toggleShowCodeCoverage()).thenAnswer(
      (_) => showCodeCoverage.value = !showCodeCoverage.value,
    );
    when(mockCodeViewController.toggleShowProfileInformation()).thenAnswer(
      (_) => showProfileHits.value = !showProfileHits.value,
    );
    when(mockCodeViewController.showCodeCoverage).thenReturn(showCodeCoverage);
    when(mockCodeViewController.showProfileInformation)
        .thenReturn(showProfileHits);
    refreshCodeCoverageInvoked = false;
    // TODO(jacobr): is there a better way to clean this up?
    // ignore: discarded_futures
    when(mockCodeViewController.refreshCodeStatistics()).thenAnswer(
      (_) async => refreshCodeCoverageInvoked = true,
    );
    when(codeViewController.navigationInProgress).thenReturn(false);
  });

  Future<void> pumpDebuggerScreen(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        DebuggerSourceAndControls(
          shownFirstScript: () => true,
          setShownFirstScript: (_) {},
        ),
        debugger: controller,
      ),
    );
  }

  void gutterItemProfileInfoTester(WidgetTester tester, bool showProfileInfo) {
    final gutterItems = tester.widgetList<ProfileInformationGutterItem>(
      find.byType(ProfileInformationGutterItem),
    );
    if (!showProfileInfo) {
      expect(gutterItems.isEmpty, true);
    } else {
      expect(gutterItems.length, profilerEntries.length);
    }
  }

  void gutterItemCoverageTester(WidgetTester tester, bool showCoverage) {
    final gutterItems = tester.widgetList<GutterItem>(find.byType(GutterItem));
    for (final item in gutterItems) {
      if (item.isExecutable) {
        expect(
          coverageHitLines.contains(item.lineNumber) ||
              coverageMissLines.contains(item.lineNumber),
          true,
        );
        if (showCoverage) {
          expect(item.coverageHit!, coverageHitLines.contains(item.lineNumber));
        } else {
          expect(item.coverageHit, isNull);
        }
      }
    }
  }

  testWidgetsWithWindowSize(
    'Gutter displays code statistics info',
    windowSize,
    (WidgetTester tester) async {
      await pumpDebuggerScreen(tester, debuggerController);

      final findCoverageToggle = find.byTooltip('Show code coverage');
      final findProfileToggle = find.byTooltip('Show profiler hits');
      final findRefresh = find.byType(RefreshButton);
      expect(findCoverageToggle, findsOneWidget);
      expect(findProfileToggle, findsOneWidget);
      expect(findRefresh, findsOneWidget);

      // Coverage display starts disabled.
      gutterItemCoverageTester(tester, false);
      gutterItemProfileInfoTester(tester, false);
      expect(
        tester.widget<DevToolsButton>(findRefresh).onPressed,
        isNull,
      );

      // Toggle showing coverage and verify the gutter items contain coverage
      // information.
      await tester.tap(findCoverageToggle);
      await pumpDebuggerScreen(tester, debuggerController);
      gutterItemCoverageTester(tester, true);
      gutterItemProfileInfoTester(tester, false);
      expect(
        tester.widget<DevToolsButton>(findRefresh).onPressed,
        isNotNull,
      );

      // Toggle showing profiler information and verify the gutter items contain
      // profiling information.
      await tester.tap(findProfileToggle);
      await pumpDebuggerScreen(tester, debuggerController);
      gutterItemCoverageTester(tester, true);
      gutterItemProfileInfoTester(tester, true);
      expect(
        tester.widget<DevToolsButton>(findRefresh).onPressed,
        isNotNull,
      );

      // Test the refresh coverage button.
      await tester.tap(findRefresh);
      await pumpDebuggerScreen(tester, debuggerController);
      expect(refreshCodeCoverageInvoked, true);

      // Toggle again and verify the coverage information is no longer present.
      await tester.tap(findCoverageToggle);
      await pumpDebuggerScreen(tester, debuggerController);
      gutterItemCoverageTester(tester, false);
      gutterItemProfileInfoTester(tester, true);
      expect(
        tester.widget<DevToolsButton>(findRefresh).onPressed,
        isNotNull,
      );

      // Toggle again and verify the profiling information is no longer present.
      await tester.tap(findProfileToggle);
      await pumpDebuggerScreen(tester, debuggerController);
      gutterItemCoverageTester(tester, false);
      gutterItemProfileInfoTester(tester, false);
      expect(
        tester.widget<DevToolsButton>(findRefresh).onPressed,
        isNull,
      );
    },
  );
}
