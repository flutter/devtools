import 'package:devtools_flutter/src/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  const contentKey = Key('Screen Content');
  const content = SizedBox(key: contentKey);

  group('Screen widget', () {
    testWidgets('displays in narrow mode without error',
        (WidgetTester tester) async {
      await setWindowSize(const Size(800.0, 1200.0));

      await tester.pumpWidget(wrap(const Screen(child: content)));
      expect(find.byKey(contentKey), findsOneWidget);
      expect(find.byKey(Screen.narrowWidth), findsOneWidget);
      expect(find.byKey(Screen.fullWidth), findsNothing);
    });

    testWidgets('displays in full-width mode without error',
        (WidgetTester tester) async {
      await setWindowSize(const Size(1203.0, 1200.0));

      await tester.pumpWidget(wrap(const Screen(child: content)));
      expect(find.byKey(contentKey), findsOneWidget);
      expect(find.byKey(Screen.fullWidth), findsOneWidget);
      expect(find.byKey(Screen.narrowWidth), findsNothing);
    });
  });
}
