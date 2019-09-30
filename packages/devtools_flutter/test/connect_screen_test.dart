// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:devtools_flutter/src/connect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  testWidgets('Connect page displays without error', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(wrap(ConnectScreen()));
    expect(find.byKey(const Key('Connect Title')), findsOneWidget);
  });
}
