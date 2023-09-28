// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(IdeTheme, IdeTheme());
  });

  group('Inspector Error Navigator', () {
    Future<void> testNavigate(
      WidgetTester tester, {
      required IconData tapIcon,
      required int errorCount,
      int? startIndex,
      int? expectedIndex,
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
      await tester.pumpWidget(
        wrap(
          ErrorNavigator(
            errorIndex: null,
            errors: _generateErrors(10),
            onSelectError: (_) {},
          ),
        ),
      );
      expect(find.text('Errors: 10'), findsOneWidget);
    });

    testWidgets('shows x/y when selected error', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          ErrorNavigator(
            errorIndex: 0,
            errors: _generateErrors(10),
            onSelectError: (_) {},
          ),
        ),
      );
      expect(find.text('Error 1/10'), findsOneWidget);
    });

    testWidgets(
      'can navigate forwards',
      // Intentionally unawaited.
      // ignore: discarded_futures
      (WidgetTester tester) => testNavigate(
        tester,
        tapIcon: Icons.keyboard_arrow_down,
        errorCount: 10,
        startIndex: 5,
        expectedIndex: 6,
      ),
    );

    testWidgets(
      'can navigate backwards',
      // Intentionally unawaited.
      // ignore: discarded_futures
      (WidgetTester tester) => testNavigate(
        tester,
        tapIcon: Icons.keyboard_arrow_up,
        errorCount: 10,
        startIndex: 5,
        expectedIndex: 4,
      ),
    );

    testWidgets(
      'wraps forwards',
      // Intentionally unawaited.
      // ignore: discarded_futures
      (WidgetTester tester) => testNavigate(
        tester,
        tapIcon: Icons.keyboard_arrow_down,
        errorCount: 10,
        startIndex: 9,
        expectedIndex: 0,
      ),
    );

    testWidgets(
      'wraps backwards',
      // Intentionally unawaited.
      // ignore: discarded_futures
      (WidgetTester tester) => testNavigate(
        tester,
        tapIcon: Icons.keyboard_arrow_up,
        errorCount: 10,
        startIndex: 0,
        expectedIndex: 9,
      ),
    );
  });
}

LinkedHashMap<String, InspectableWidgetError> _generateErrors(int count) =>
    LinkedHashMap<String, InspectableWidgetError>.fromEntries(
      List.generate(
        count,
        (index) => MapEntry(
          'error-$index',
          InspectableWidgetError(
            'Error $index',
            'error-$index',
          ),
        ),
      ),
    );
