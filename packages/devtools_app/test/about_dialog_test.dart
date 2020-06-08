// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools.dart' as devtools;
import 'package:devtools_app/src/app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/utils.dart';
import 'support/wrappers.dart';

void main() {
  DevToolsAboutDialog aboutDialog;

  group('About Dialog', () {
    setUp(() {
      aboutDialog = DevToolsAboutDialog();
    });

    testWidgets('builds dialog', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(aboutDialog));
      expect(find.text('About DevTools'), findsOneWidget);
    });

    testWidgets('DevTools section', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(aboutDialog));
      expect(find.text('About DevTools'), findsOneWidget);
      expect(findSubstring(aboutDialog, devtools.version), findsOneWidget);
    });

    testWidgets('Feedback section', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(aboutDialog));
      expect(find.text('Feedback'), findsOneWidget);
      expect(findSubstring(aboutDialog, 'github.com/flutter/devtools'),
          findsOneWidget);
    });
  });
}
