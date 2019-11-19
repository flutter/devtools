// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/logging/flutter/logging_screen.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/service_extensions.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/flutter/service_extension_widgets.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  LoggingScreen screen;
  group('Info Screen', () {
    MockLoggingController mockLoggingController;
    Widget wrap(Widget widget) =>
        wrapWithControllers(widget, loggingController: mockLoggingController);

    setUp(() async {
      await ensureInspectorDependencies();
      mockLoggingController = MockLoggingController();
      when(mockLoggingController.data).thenReturn([]);
      when(mockLoggingController.onLogsUpdated).thenReturn(Notifier());

      setGlobal(
        ServiceConnectionManager,
        FakeServiceManager(useFakeService: true),
      );
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));

      screen = const LoggingScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Logging'), findsOneWidget);
    });

    testWidgets('builds with no data', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(LoggingScreenBody), findsOneWidget);
      expect(find.text('Clear logs'), findsOneWidget);
      expect(find.byType(StructuredErrorsToggle), findsOneWidget);
    });

    testWidgets('can clear logs', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      verifyNever(mockLoggingController.clear());
      await tester.tap(find.text('Clear logs'));
      verify(mockLoggingController.clear()).called(1);
    });

    testWidgets('can toggle structured errors', (WidgetTester tester) async {
      final serviceManager = FakeServiceManager(useFakeService: false);
      setGlobal(
        ServiceConnectionManager,
        serviceManager,
      );
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      Switch toggle = tester.widget(find.byType(Switch));
      expect(toggle.value, false);

      serviceManager.serviceExtensionManager
          .fakeServiceExtensionStateChanged(structuredErrors.extension, 'true');
      await tester.pumpAndSettle();
      toggle = tester.widget(find.byType(Switch));
      expect(toggle.value, true);

      // TODO(djshuckerow): Hook up fake extension state querying.
    });

    testWidgets('shows most recent logs first', (WidgetTester tester) async {
      when(mockLoggingController.data).thenReturn(fakeLogData);
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      await tester.pumpAndSettle();
      expect(find.byType(LogsTable), findsOneWidget);
      expect(find.byKey(ValueKey(fakeLogData.last)), findsOneWidget,
          reason: 'the most recently added logdata should show in the list by '
              'default.');
      expect(find.byKey(ValueKey(fakeLogData.first)), findsNothing,
          reason:
              'the least recently added logdata should be at the top of the '
              'list, hidden from view.');
    });
  });
}

final fakeLogData =
    List<LogData>.generate(1000, (i) => LogData('kind $i', 'log event $i', i));
