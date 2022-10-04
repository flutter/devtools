// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/analytics/analytics_controller.dart';
import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/framework/scaffold.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/screen.dart';
import 'package:devtools_app/src/shared/survey.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  final mockServiceManager = MockServiceConnectionManager();
  when(mockServiceManager.service).thenReturn(null);
  when(mockServiceManager.connectedAppInitialized).thenReturn(false);
  when(mockServiceManager.connectedState).thenReturn(
    ValueNotifier<ConnectedState>(const ConnectedState(false)),
  );

  final mockErrorBadgeManager = MockErrorBadgeManager();
  when(mockServiceManager.errorBadgeManager).thenReturn(mockErrorBadgeManager);
  when(mockErrorBadgeManager.errorCountNotifier(any))
      .thenReturn(ValueNotifier<int>(0));

  setGlobal(ServiceConnectionManager, mockServiceManager);
  setGlobal(FrameworkController, FrameworkController());
  setGlobal(SurveyService, SurveyService());
  setGlobal(OfflineModeController, OfflineModeController());
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(NotificationService, NotificationService());

  testWidgets(
      'does not display floating debugger controls when debugger screen is showing',
      (WidgetTester tester) async {
    final mockConnectedApp = MockConnectedAppLegacy();
    when(mockConnectedApp.isFlutterAppNow).thenReturn(true);
    when(mockConnectedApp.isProfileBuildNow).thenReturn(false);
    when(mockServiceManager.connectedAppInitialized).thenReturn(true);
    when(mockServiceManager.connectedApp).thenReturn(mockConnectedApp);
    final mockDebuggerController = MockDebuggerController();
    when(mockDebuggerController.isPaused)
        .thenReturn(ValueNotifier<bool>(false));

    const debuggerScreenKey = Key('debugger screen');
    const debuggerTabKey = Key('debugger tab');
    await tester.pumpWidget(
      wrapWithControllers(
        DevToolsScaffold(
          tabs: const [
            _TestScreen(
              DebuggerScreen.id,
              debuggerScreenKey,
              tabKey: debuggerTabKey,
              showFloatingDebuggerControls: false,
            ),
            _screen2,
          ],
          ideTheme: IdeTheme(),
        ),
        debugger: mockDebuggerController,
        analytics: AnalyticsController(enabled: false, firstRun: false),
      ),
    );
    expect(find.byKey(debuggerScreenKey), findsOneWidget);
    expect(find.byKey(_k2), findsNothing);
    expect(find.byType(FloatingDebuggerControls), findsNothing);

    // Tap on the tab for screen 2 and verify the controls are present.
    await tester.tap(find.byKey(_t2));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.byKey(debuggerScreenKey), findsNothing);
    expect(find.byKey(_k2), findsOneWidget);
    expect(find.byType(FloatingDebuggerControls), findsOneWidget);

    // Return to the debugger screen and verify the controls are gone.
    await tester.tap(find.byKey(debuggerTabKey));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.byKey(debuggerScreenKey), findsOneWidget);
    expect(find.byKey(_k2), findsNothing);
    expect(find.byType(FloatingDebuggerControls), findsNothing);
  });
}

class _TestScreen extends Screen {
  const _TestScreen(
    this.name,
    this.key, {
    bool showFloatingDebuggerControls = true,
    Key? tabKey,
  }) : super(
          name,
          title: name,
          icon: Icons.computer,
          tabKey: tabKey,
          showFloatingDebuggerControls: showFloatingDebuggerControls,
        );

  final String name;
  final Key key;

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: key);
  }
}

// Keys and tabs for use in the test.
const _k2 = Key('body key 2');
const _t2 = Key('tab key 2');
const _screen2 = _TestScreen('screen2', _k2, tabKey: _t2);
