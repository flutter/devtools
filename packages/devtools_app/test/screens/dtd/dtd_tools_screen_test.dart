// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DTDToolsScreen screen;
  late DTDToolsController dtdToolsController;
  const windowSize = Size(1500.0, 1500.0);

  group('$DTDToolsScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          const DTDToolsScreenBody(),
          dtdTools: dtdToolsController,
        ),
      );
    }

    setUp(() {
      dtdToolsController = DTDToolsController();
      screen = DTDToolsScreen();
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('DTD Tools'), findsOneWidget);
      expect(find.byIcon(Icons.settings_applications), findsOneWidget);
    });

    testWidgetsWithWindowSize('builds with no DTD connection', windowSize, (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
    });

    testWidgetsWithWindowSize(
      'builds for existing DTD connection',
      windowSize,
      (WidgetTester tester) async {
        await pumpScreen(tester);
      },
    );

    testWidgetsWithWindowSize(
      'can disconnect from existing connection and connect to a different one',
      windowSize,
      (WidgetTester tester) async {
        await pumpScreen(tester);
      },
    );
  });
}
