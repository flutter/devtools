// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/analytics/stub_provider.dart';
import 'package:devtools_app/src/framework_controller.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/scaffold.dart';
import 'package:devtools_app/src/screen.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/survey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  group('DevToolsScaffold widget', () {
    MockServiceManager mockServiceManager;

    setUp(() {
      mockServiceManager = MockServiceManager();
      when(mockServiceManager.service).thenReturn(null);
      when(mockServiceManager.onStateChange)
          .thenAnswer((_) => const Stream<bool>.empty());
      setGlobal(ServiceConnectionManager, mockServiceManager);
      setGlobal(FrameworkController, FrameworkController());
      setGlobal(SurveyService, SurveyService());
    });

    testWidgetsWithWindowSize('displays in narrow mode without error',
        const Size(DevToolsScaffold.narrowWidthThreshold - 200.0, 1200.0),
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        DevToolsScaffold(
          tabs: const [screen1, screen2, screen3, screen4, screen5],
          ideTheme: null,
          analyticsProvider: await analyticsProvider,
        ),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.fullWidthKey), findsNothing);
    });

    testWidgetsWithWindowSize('displays in full-width mode without error',
        const Size(DevToolsScaffold.narrowWidthThreshold + 3.0, 1200.0),
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        DevToolsScaffold(
          tabs: const [screen1, screen2, screen3, screen4, screen5],
          ideTheme: null,
          analyticsProvider: await analyticsProvider,
        ),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.fullWidthKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsNothing);
    });

    testWidgets('displays no tabs when only one is given',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        DevToolsScaffold(
          tabs: const [screen1],
          ideTheme: null,
          analyticsProvider: await analyticsProvider,
        ),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(t1), findsNothing);
    });

    testWidgets('displays only the selected tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        DevToolsScaffold(
          tabs: const [screen1, screen2],
          ideTheme: null,
          analyticsProvider: await analyticsProvider,
        ),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(k2), findsNothing);

      // Tap on the tab for screen 2, then let the animation finish before
      // checking the body is updated.
      await tester.tap(find.byKey(t2));
      await tester.pumpAndSettle();
      expect(find.byKey(k1), findsNothing);
      expect(find.byKey(k2), findsOneWidget);

      // Return to screen 1.
      await tester.tap(find.byKey(t1));
      await tester.pumpAndSettle();
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(k2), findsNothing);
    });

    testWidgets('displays the requested initial page',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        DevToolsScaffold(
          tabs: const [screen1, screen2],
          page: screen2.screenId,
          ideTheme: null,
          analyticsProvider: await analyticsProvider,
        ),
      ));

      expect(find.byKey(k1), findsNothing);
      expect(find.byKey(k2), findsOneWidget);
    });
  });
}

class _TestScreen extends Screen {
  const _TestScreen(this.name, this.key, {Key tabKey})
      : super(
          'testScreen$name',
          title: name,
          icon: Icons.computer,
          tabKey: tabKey,
        );

  final String name;
  final Key key;

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: key);
  }
}

// Keys and tabs for use in the test.
const k1 = Key('body key 1');
const k2 = Key('body key 2');
const k3 = Key('body key 3');
const k4 = Key('body key 4');
const k5 = Key('body key 5');
const t1 = Key('tab key 1');
const t2 = Key('tab key 2');
const message1Key = Key('test message 1');
const message2Key = Key('test message 2');
const screen1 = _TestScreen('screen1', k1, tabKey: t1);
const screen2 = _TestScreen('screen2', k2, tabKey: t2);
const screen3 = _TestScreen('screen3', k3);
const screen4 = _TestScreen('screen4', k4);
const screen5 = _TestScreen('screen5', k5);
