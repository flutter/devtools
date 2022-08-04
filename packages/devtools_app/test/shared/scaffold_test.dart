// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/config_specific/import_export/import_export.dart';
import 'package:devtools_app/src/framework/notifications.dart';
import 'package:devtools_app/src/primitives/notifications.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/framework_controller.dart';
import 'package:devtools_app/src/shared/globals.dart';
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
  setGlobal(NotificationService, NotificationController());

  Widget wrapScaffold(Widget child) {
    return wrap(wrapWithAnalytics(child));
  }

  testWidgetsWithWindowSize(
      'displays in narrow mode without error', const Size(200.0, 1200.0),
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapScaffold(
        wrapWithNotifications(
          DevToolsScaffold(
            tabs: const [_screen1, _screen2, _screen3, _screen4, _screen5],
            ideTheme: IdeTheme(),
          ),
        ),
      ),
    );
    expect(find.byKey(_k1), findsOneWidget);
    expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsOneWidget);
    expect(find.byKey(DevToolsScaffold.fullWidthKey), findsNothing);
  });

  testWidgetsWithWindowSize(
      'displays in full-width mode without error', const Size(1200.0, 1200.0),
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapScaffold(
        wrapWithNotifications(
          DevToolsScaffold(
            tabs: const [_screen1, _screen2, _screen3, _screen4, _screen5],
            ideTheme: IdeTheme(),
          ),
        ),
      ),
    );
    expect(find.byKey(_k1), findsOneWidget);
    expect(find.byKey(DevToolsScaffold.fullWidthKey), findsOneWidget);
    expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsNothing);
  });

  testWidgets('displays no tabs when only one is given',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapScaffold(
        wrapWithNotifications(
          DevToolsScaffold(
            tabs: const [_screen1],
            ideTheme: IdeTheme(),
          ),
        ),
      ),
    );
    expect(find.byKey(_k1), findsOneWidget);
    expect(find.byKey(_t1), findsNothing);
  });

  testWidgets('displays only the selected tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapScaffold(
        wrapWithNotifications(
          DevToolsScaffold(
            tabs: const [_screen1, _screen2],
            ideTheme: IdeTheme(),
          ),
        ),
      ),
    );
    expect(find.byKey(_k1), findsOneWidget);
    expect(find.byKey(_k2), findsNothing);

    // Tap on the tab for screen 2, then let the animation finish before
    // checking the body is updated.
    await tester.tap(find.byKey(_t2));
    await tester.pumpAndSettle();
    expect(find.byKey(_k1), findsNothing);
    expect(find.byKey(_k2), findsOneWidget);

    // Return to screen 1.
    await tester.tap(find.byKey(_t1));
    await tester.pumpAndSettle();
    expect(find.byKey(_k1), findsOneWidget);
    expect(find.byKey(_k2), findsNothing);
  });

  testWidgets('displays the requested initial page',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapScaffold(
        wrapWithNotifications(
          DevToolsScaffold(
            tabs: const [_screen1, _screen2],
            page: _screen2.screenId,
            ideTheme: IdeTheme(),
          ),
        ),
      ),
    );

    expect(find.byKey(_k1), findsNothing);
    expect(find.byKey(_k2), findsOneWidget);
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
const _k1 = Key('body key 1');
const _k2 = Key('body key 2');
const _k3 = Key('body key 3');
const _k4 = Key('body key 4');
const _k5 = Key('body key 5');
const _t1 = Key('tab key 1');
const _t2 = Key('tab key 2');
const _screen1 = _TestScreen('screen1', _k1, tabKey: _t1);
const _screen2 = _TestScreen('screen2', _k2, tabKey: _t2);
const _screen3 = _TestScreen('screen3', _k3);
const _screen4 = _TestScreen('screen4', _k4);
const _screen5 = _TestScreen('screen5', _k5);
