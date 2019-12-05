// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/scaffold.dart';
import 'package:devtools_app/src/flutter/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  group('DevToolsScaffold widget', () {
    testWidgetsWithWindowSize(
        'displays in narrow mode without error', const Size(800.0, 1200.0),
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const DevToolsScaffold(
          tabs: [screen1, screen2, screen3, screen4, screen5],
        ),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.fullWidthKey), findsNothing);
    });

    testWidgetsWithWindowSize(
        'displays in full-width mode without error', const Size(1203.0, 1200.0),
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const DevToolsScaffold(
          tabs: [screen1, screen2, screen3, screen4, screen5],
        ),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.fullWidthKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsNothing);
    });

    testWidgets('displays no tabs when only one is given',
        (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const DevToolsScaffold(tabs: [screen1]),
      ));
      expect(find.byKey(k1), findsOneWidget);
      expect(find.byKey(t1), findsNothing);
    });

    testWidgets('displays only the selected tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        const DevToolsScaffold(
          tabs: [screen1, screen2],
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
  });
}

class _TestScreen extends Screen {
  const _TestScreen(this.name, this.key, [this.tabKey]) : super();

  static const contentKey = Key('DevToolsScaffold Content');

  final String name;
  final Key key;
  final Key tabKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: key);
  }

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      key: tabKey,
      text: name,
      icon: const Icon(Icons.computer),
    );
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
const screen1 = _TestScreen('screen1', k1, t1);
const screen2 = _TestScreen('screen2', k2, t2);
const screen3 = _TestScreen('screen3', k3);
const screen4 = _TestScreen('screen4', k4);
const screen5 = _TestScreen('screen5', k5);
