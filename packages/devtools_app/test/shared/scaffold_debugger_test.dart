// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/scaffold.dart';
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_app/src/shared/survey.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockServiceConnectionManager mockServiceConnection;
  late MockServiceManager mockServiceManager;

  setUp(() {
    mockServiceConnection = createMockServiceConnectionWithDefaults();
    mockServiceManager =
        mockServiceConnection.serviceManager as MockServiceManager;
    when(mockServiceManager.service).thenReturn(null);
    when(mockServiceManager.connectedState).thenReturn(
      ValueNotifier<ConnectedState>(const ConnectedState(false)),
    );
    when(mockServiceManager.hasConnection).thenReturn(false);
    when(mockServiceManager.isolateManager).thenReturn(FakeIsolateManager());
    when(mockServiceConnection.appState).thenReturn(
      AppState(
        mockServiceManager.isolateManager.selectedIsolate,
      ),
    );

    final mockErrorBadgeManager = MockErrorBadgeManager();
    when(mockServiceConnection.errorBadgeManager)
        .thenReturn(mockErrorBadgeManager);
    when(mockErrorBadgeManager.errorCountNotifier(any))
        .thenReturn(ValueNotifier<int>(0));
    when(mockServiceManager.isMainIsolatePaused).thenReturn(false);

    setGlobal(ServiceConnectionManager, mockServiceConnection);
    setGlobal(FrameworkController, FrameworkController());
    setGlobal(SurveyService, SurveyService());
    setGlobal(OfflineDataController, OfflineDataController());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
  });

  testWidgets(
    'does not display floating debugger controls when debugger screen is showing',
    (WidgetTester tester) async {
      final connectedApp = MockConnectedApp();
      mockConnectedApp(
        connectedApp,
        isFlutterApp: true,
        isProfileBuild: false,
        isWebApp: false,
      );
      when(mockServiceManager.connectedAppInitialized).thenReturn(true);
      when(mockServiceManager.connectedApp).thenReturn(connectedApp);
      final mockDebuggerController = MockDebuggerController();

      const debuggerScreenKey = Key('debugger screen');
      const debuggerTabKey = Key('debugger tab');
      await tester.pumpWidget(
        wrapWithControllers(
          DevToolsScaffold(
            page: DebuggerScreen.id,
            screens: [
              _TestScreen(
                DebuggerScreen.id,
                debuggerScreenKey,
                tabKey: debuggerTabKey,
                showFloatingDebuggerControls: false,
              ),
              _screen2,
            ],
          ),
          debugger: mockDebuggerController,
          analytics: AnalyticsController(
            enabled: false,
            shouldShowConsentMessage: false,
            consentMessage: 'fake message',
          ),
          releaseNotes: ReleaseNotesController(),
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
    },
  );
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
  Widget buildScreenBody(BuildContext context) {
    return SizedBox(key: key);
  }
}

// Keys and tabs for use in the test.
const _k2 = Key('body key 2');
const _t2 = Key('tab key 2');
const _screen2 = _TestScreen('screen2', _k2, tabKey: _t2);
