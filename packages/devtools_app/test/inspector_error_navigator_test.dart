// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:devtools_app/src/error_badge_manager.dart';
import 'package:devtools_app/src/inspector/inspector_screen.dart';
import 'package:devtools_app/src/inspector/inspector_tree.dart';
import 'package:devtools_app/src/listenable.dart';
import 'package:flutter/foundation.dart';
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
      final index = ValueNotifier<int>(startIndex);
      final navigator = ErrorNavigator(
        selectedErrorIndex: index,
        errors: _generateErrors(errorCount),
        selectedNode: const FixedValueListenable<InspectorTreeNode>(null),
      );

      await tester.pumpWidget(wrap(navigator));
      await tester.tap(find.byIcon(tapIcon));

      expect(index.value, equals(expectedIndex));
    }

    testWidgets('shows count when no selection', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(ErrorNavigator(
        selectedErrorIndex: ValueNotifier<int>(null),
        errors: _generateErrors(10),
        selectedNode: const FixedValueListenable<InspectorTreeNode>(null),
      )));
      expect(find.text('Errors: 10'), findsOneWidget);
    });

    testWidgets('shows x/y when selected error', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(ErrorNavigator(
        selectedErrorIndex: ValueNotifier<int>(0),
        errors: _generateErrors(10),
        selectedNode: const FixedValueListenable<InspectorTreeNode>(null),
      )));
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
