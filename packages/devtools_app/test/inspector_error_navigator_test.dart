// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:collection';

import 'package:devtools_app/src/inspector/inspector_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/error_badge_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceManager());
  });

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
        errorIndex: index,
        errors: _generateErrors(errorCount),
        onSelectError: (newIndex) => index = newIndex,
      );

      await tester.pumpWidget(wrap(navigator));
      await tester.tap(find.byIcon(tapIcon));

      expect(index, equals(expectedIndex));
    }

    testWidgets('shows count when no selection', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        ErrorNavigator(
            errorIndex: null,
            errors: _generateErrors(10),
            onSelectError: (_) {}),
      ));
      expect(find.text('Errors: 10'), findsOneWidget);
    });

    testWidgets('shows x/y when selected error', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(
        ErrorNavigator(
            errorIndex: 0, errors: _generateErrors(10), onSelectError: (_) {}),
      ));
      expect(find.text('Error 1/10'), findsOneWidget);
    });

    testWidgets(
        'can navigate forwards',
        (WidgetTester tester) => testNavigate(tester,
            tapIcon: Icons.keyboard_arrow_down,
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
            tapIcon: Icons.keyboard_arrow_up,
            errorCount: 10,
            startIndex: 0,
            expectedIndex: 9));
  });
}

LinkedHashMap<String, InspectableWidgetError> _generateErrors(int count) =>
    LinkedHashMap<String, InspectableWidgetError>.fromEntries(List.generate(
      count,
      (index) => MapEntry(
        'error-$index',
        InspectableWidgetError(
          'Error $index',
          'error-$index',
        ),
      ),
    ));
