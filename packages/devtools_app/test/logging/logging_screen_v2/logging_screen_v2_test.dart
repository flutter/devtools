// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_table_v2.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late LoggingScreenV2 screen;
  late MockLoggingControllerV2 mockLoggingController;
  const windowSize = Size(1000.0, 1000.0);

  group('Logging Screen', () {
    Future<void> pumpLoggingScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          const LoggingScreenBodyV2(),
          loggingV2: mockLoggingController,
        ),
      );
    }

    setUp(() {
      mockLoggingController = createMockLoggingControllerV2WithDefaults();

      final fakeServiceConnection = FakeServiceConnectionManager();
      when(
        fakeServiceConnection.serviceManager.connectedApp!.isFlutterWebAppNow,
      ).thenReturn(false);
      when(fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow)
          .thenReturn(false);
      when(
        fakeServiceConnection.errorBadgeManager.errorCountNotifier('logging'),
      ).thenReturn(ValueNotifier<int>(0));
      setGlobal(NotificationService, NotificationService());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(IdeTheme, IdeTheme());

      screen = LoggingScreenV2();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Logging'), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'builds with no data',
      windowSize,
      (WidgetTester tester) async {
        await pumpLoggingScreen(tester);
        expect(find.byType(LoggingScreenBodyV2), findsOneWidget);
        expect(find.byType(LoggingTableV2), findsOneWidget);
      },
    );
  });
}
