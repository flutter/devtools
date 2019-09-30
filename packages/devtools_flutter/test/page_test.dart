// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:devtools_flutter/src/page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  const contentKey = Key('Page Content');
  const content = SizedBox(key: contentKey);

  group('Page widget', () {
    testWidgets('displays in narrow mode without error',
        (WidgetTester tester) async {
      await setWindowSize(const Size(800.0, 1200.0));

      await tester.pumpWidget(wrap(
        const Page(child: content)
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(contentKey), findsOneWidget);
      expect(find.byKey(Page.narrowWidth), findsOneWidget);
      expect(find.byKey(Page.fullWidth), findsNothing);
    });

    testWidgets('displays in full-width mode without error',
        (WidgetTester tester) async {
      await setWindowSize(const Size(900.0, 1200.0));

      await tester.pumpWidget(wrap(
        const Page(child: content)
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(contentKey), findsOneWidget);
      expect(find.byKey(Page.fullWidth), findsOneWidget);
      expect(find.byKey(Page.narrowWidth), findsNothing);
    });
  });
}
