// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools.dart' as devtools;
import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/extension_points/extensions_base.dart';
import 'package:devtools_app/src/extension_points/extensions_external.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/about_dialog.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DevToolsAboutDialog aboutDialog;

  group('About Dialog', () {
    setUp(() {
      aboutDialog = DevToolsAboutDialog();
      setGlobal(DevToolsExtensionPoints, ExternalDevToolsExtensionPoints());
      setGlobal(ServiceConnectionManager, FakeServiceManager());
      setGlobal(IdeTheme, IdeTheme());
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
      expect(
        findSubstring(aboutDialog, 'github.com/flutter/devtools'),
        findsOneWidget,
      );
    });
  });
}
