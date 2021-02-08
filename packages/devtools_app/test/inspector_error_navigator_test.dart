// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/inspector/inspector_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/wrappers.dart';

void main() {
  group('Inspector Error Navigator', () {
    Future<void> testNavigate(
      WidgetTester tester, {
      IconData tapIcon,
      int errorCount,
      int startIndex,
      int expectedIndex,
    }) async {
      var index = startIndex;
      final navigator = ErrorNavigator(
        selectedErrorIndex: startIndex,
        errorCount: errorCount,
        onSelectedErrorIndexChanged: (newIndex) => index = newIndex,
      );

      await tester.pumpWidget(wrap(navigator));
      await tester.tap(find.byIcon(tapIcon));

      expect(index, equals(expectedIndex));
    }

    testWidgets('shows count when no selection', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const ErrorNavigator(
        selectedErrorIndex: null,
        errorCount: 10,
        onSelectedErrorIndexChanged: null,
      )));
      expect(find.text('Errors: 10'), findsOneWidget);
    });

    testWidgets('shows x/y when selected error', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const ErrorNavigator(
        selectedErrorIndex: 0,
        errorCount: 10,
        onSelectedErrorIndexChanged: null,
      )));
      expect(find.text('Error 1/10'), findsOneWidget);
    });

    testWidgets(
        'can navigate forwards',
        (WidgetTester tester) => testNavigate(tester,
            tapIcon: Icons.chevron_right,
            errorCount: 10,
            startIndex: 5,
            expectedIndex: 6));

    testWidgets(
        'can navigate backwards',
        (WidgetTester tester) => testNavigate(tester,
            tapIcon: Icons.keyboard_arrow_up,
            errorCount: 10,
            startIndex: 5,
            expectedIndex: 4));

    testWidgets(
        'wraps forwards',
        (WidgetTester tester) => testNavigate(tester,
            tapIcon: Icons.keyboard_arrow_down,
            errorCount: 10,
            startIndex: 9,
            expectedIndex: 0));

    testWidgets(
        'wraps backwards',
        (WidgetTester tester) => testNavigate(tester,
            tapIcon: Icons.chevron_left,
            errorCount: 10,
            startIndex: 0,
            expectedIndex: 9));
  });
}
