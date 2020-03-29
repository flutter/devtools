// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools.dart' as devtools;
import 'package:devtools_app/src/flutter/app.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  DevToolsAboutDialog aboutDialog;
  FakeServiceManager fakeServiceManager;

  group('About Dialog', () {
    setUp(() {
      fakeServiceManager = FakeServiceManager(useFakeService: true);
      when(fakeServiceManager.connectedApp.isDartWebAppNow).thenReturn(false);
      setGlobal(ServiceConnectionManager, fakeServiceManager);
      mockIsFlutterApp(serviceManager.connectedApp);
      aboutDialog = DevToolsAboutDialog();
    });

    testWidgets('builds dialog', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(aboutDialog));
      expect(find.text('DevTools'), findsOneWidget);
    });

    testWidgets('DevTools section', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(aboutDialog));
      expect(find.text('DevTools'), findsOneWidget);
      expect(_findSubstring(aboutDialog, devtools.version), findsOneWidget);
    });

    testWidgets('Device Info section', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(aboutDialog));
      expect(_findSubstring(aboutDialog, 'Device Info'), findsOneWidget);
      // TODO(devoncarew): Improve testing wrt InfoController.
      expect(_findSubstring(aboutDialog, 'No Flutter device connected'),
          findsOneWidget);
    });

    testWidgets('Feedback section', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(aboutDialog));
      expect(find.text('Feedback'), findsOneWidget);
      expect(_findSubstring(aboutDialog, 'github.com/flutter/devtools'),
          findsOneWidget);
    });
  });
}

Finder _findSubstring(Widget widget, String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is Text) {
      final Text textWidget = widget;
      if (textWidget.data != null) return textWidget.data.contains(text);
      return textWidget.textSpan.toPlainText().contains(text);
    } else if (widget is SelectableText) {
      final SelectableText textWidget = widget;
      if (textWidget.data != null) return textWidget.data.contains(text);
    }

    return false;
  });
}
