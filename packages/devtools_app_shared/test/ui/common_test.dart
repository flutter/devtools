// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

void main() {
  setUp(() {
    setGlobal(IdeTheme, IdeTheme());
  });

  group('AreaPaneHeader', () {
    const titleText = 'The title';

    testWidgets(
      'actions do not take up space when not present',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            const AreaPaneHeader(
              title: Text(titleText),
            ),
          ),
        );

        final row = tester.widget(find.byType(Row)) as Row;
        expect(
          row.children.length,
          equals(1),
        );
        expect(
          find.text(titleText),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows actions', (WidgetTester tester) async {
      const actionText = 'The Action Text';
      const action = Text(actionText);

      await tester.pumpWidget(
        wrap(
          const AreaPaneHeader(
            title: Text(titleText),
            actions: [action],
          ),
        ),
      );

      final row = tester.widget(find.byType(Row)) as Row;
      expect(
        row.children.length,
        equals(2),
      );
      expect(find.text(actionText), findsOneWidget);
      expect(
        find.text(titleText),
        findsOneWidget,
      );
    });
  });
}
