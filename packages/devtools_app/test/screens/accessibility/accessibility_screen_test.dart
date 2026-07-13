// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late AccessibilityScreen screen;
  late AccessibilityController controller;
  const windowSize = Size(1000.0, 1000.0);

  group('Accessibility Screen', () {
    Future<void> pumpAccessibilityScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          const AccessibilityScreenBody(),
          accessibility: controller,
        ),
      );
    }

    setUp(() {
      final fakeServiceConnection = FakeServiceConnectionManager();
      when(
        fakeServiceConnection.serviceManager.connectedApp!.isFlutterWebAppNow,
      ).thenReturn(false);
      when(
        fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow,
      ).thenReturn(false);
      when(
        fakeServiceConnection.errorBadgeManager.errorCountNotifier(
          'accessibility',
        ),
      ).thenReturn(ValueNotifier<int>(0));

      setGlobal(NotificationService, NotificationService());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(IdeTheme, IdeTheme());

      controller = AccessibilityController();
      screen = AccessibilityScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Accessibility'), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds split view with panes', windowSize, (
      WidgetTester tester,
    ) async {
      await pumpAccessibilityScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AccessibilityScreenBody), findsOneWidget);
      expect(find.byType(SplitPane), findsAtLeastNWidgets(1));

      // Overrides pane should be visible and contain placeholder text
      expect(find.text('Accessibility Overrides'), findsOneWidget);
      expect(
        find.textContaining('Accessibility overrides placeholder.'),
        findsOneWidget,
      );

      // Semantics Tree pane should be visible and contain placeholder text
      expect(find.text('Semantics Tree'), findsOneWidget);
      expect(
        find.textContaining('Accessibility semantics tree placeholder.'),
        findsOneWidget,
      );
    });
  });
}
