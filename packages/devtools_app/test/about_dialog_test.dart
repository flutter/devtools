// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools.dart' as devtools;
import 'package:devtools_app/src/app.dart';
import 'package:devtools_app/src/extension_points/extensions_base.dart';
import 'package:devtools_app/src/extension_points/extensions_external.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_test/mocks.dart';
import 'package:devtools_test/utils.dart';
import 'package:devtools_test/wrappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DevToolsAboutDialog aboutDialog;

  group('About Dialog', () {
    setUp(() {
      aboutDialog = DevToolsAboutDialog();
      setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
      setGlobal(ServiceConnectionManager, FakeServiceManager());
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
