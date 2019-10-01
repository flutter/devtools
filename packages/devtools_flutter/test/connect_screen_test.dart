import 'package:devtools_flutter/src/connect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  testWidgets('Connect screen displays without error', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(wrap(ConnectScreen()));
    expect(find.byKey(const Key('Connect Title')), findsOneWidget);
  });
}
