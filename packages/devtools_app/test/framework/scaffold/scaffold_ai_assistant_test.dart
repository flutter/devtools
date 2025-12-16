// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/scaffold/scaffold.dart';
import 'package:devtools_app/src/shared/ai_assistant/widgets/ai_assistant_pane.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/shared/framework/framework_controller.dart';
import 'package:devtools_app/src/shared/managers/survey.dart';
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
    when(
      mockServiceManager.connectedState,
    ).thenReturn(ValueNotifier<ConnectedState>(const ConnectedState(false)));
    final mockErrorBadgeManager = MockErrorBadgeManager();
    when(
      mockServiceConnection.errorBadgeManager,
    ).thenReturn(mockErrorBadgeManager);
    when(
      mockErrorBadgeManager.errorCountNotifier(any),
    ).thenReturn(ValueNotifier<int>(0));

    setGlobal(ServiceConnectionManager, mockServiceConnection);
    setGlobal(FrameworkController, FrameworkController());
    setGlobal(SurveyService, SurveyService());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
  });

  Future<void> pumpScaffold(
    WidgetTester tester, {
    required Screen screen,
    bool withConnectedApp = true,
    bool withOfflineData = false,
  }) async {
    if (withOfflineData) {
      final offlineController = MockOfflineDataController();
      offlineController.showingOfflineData.value = true;
      setGlobal(OfflineDataController, offlineController);
    }

    MockConnectedApp? connectedApp;
    if (withConnectedApp) {
      connectedApp = MockConnectedApp();
      mockConnectedApp(connectedApp);
    }
    when(
      mockServiceManager.connectedAppInitialized,
    ).thenReturn(withConnectedApp);
    when(mockServiceManager.connectedApp).thenReturn(connectedApp);

    await tester.pumpWidget(
      wrapWithControllers(
        DevToolsScaffold(screens: [screen]),
        analytics: AnalyticsController(
          enabled: false,
          shouldShowConsentMessage: false,
          consentMessage: 'fake message',
        ),
      ),
    );
  }

  group('AI Assistant pane', () {
    testWidgets('is visible for supported screens', (
      WidgetTester tester,
    ) async {
      FeatureFlags.aiAssists.setEnabledForTests(true);

      await pumpScaffold(tester, screen: const _TestScreenWithAi());

      expect(find.byType(AiAssistantPane), findsOneWidget);
    });

    testWidgets('is not visible for unsupported screens', (
      WidgetTester tester,
    ) async {
      FeatureFlags.aiAssists.setEnabledForTests(true);

      await pumpScaffold(tester, screen: const _TestScreenWithoutAi());

      expect(find.byType(AiAssistantPane), findsNothing);
    });

    testWidgets('is not visible when app is not connected', (
      WidgetTester tester,
    ) async {
      FeatureFlags.aiAssists.setEnabledForTests(true);

      await pumpScaffold(
        tester,
        screen: const _TestScreenWithAi(),
        withConnectedApp: false,
      );

      expect(find.byType(AiAssistantPane), findsNothing);
    });

    testWidgets('is not visible when feature flag is disabled', (
      WidgetTester tester,
    ) async {
      FeatureFlags.aiAssists.setEnabledForTests(false);

      await pumpScaffold(tester, screen: const _TestScreenWithAi());

      expect(find.byType(AiAssistantPane), findsNothing);
    });

    testWidgets('is not visible when in offline mode', (
      WidgetTester tester,
    ) async {
      FeatureFlags.aiAssists.setEnabledForTests(true);

      await pumpScaffold(
        tester,
        screen: const _TestScreenWithAi(),
        withOfflineData: true,
      );

      expect(find.byType(AiAssistantPane), findsNothing);
    });
  });
}

class _TestScreenWithAi extends Screen {
  const _TestScreenWithAi()
    : super('test_screen_with_ai', showFloatingDebuggerControls: false);

  @override
  bool showAiAssistant() => true;

  @override
  Widget buildScreenBody(BuildContext context) => const SizedBox();
}

class _TestScreenWithoutAi extends Screen {
  const _TestScreenWithoutAi()
    : super('test_screen_without_ai', showFloatingDebuggerControls: false);

  @override
  Widget buildScreenBody(BuildContext context) => const SizedBox();
}
