// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/extensions/embedded/view.dart';
import 'package:devtools_app/src/extensions/extension_screen.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/test_data/extensions.dart';

void main() {
  const windowSize = Size(2000.0, 2000.0);
  group('Extension screen', () {
    late ExtensionScreen fooScreen;
    late ExtensionScreen barScreen;
    late ExtensionScreen providerScreen;

    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(ServiceConnectionManager, ServiceConnectionManager());
      fooScreen = ExtensionScreen(fooExtension);
      barScreen = ExtensionScreen(barExtension);
      providerScreen = ExtensionScreen(providerExtension);
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: fooScreen.buildTab)));
      expect(find.text('Foo'), findsOneWidget);
      expect(find.byIcon(fooExtension.icon), findsOneWidget);

      await tester.pumpWidget(wrap(Builder(builder: barScreen.buildTab)));
      expect(find.text('Bar'), findsOneWidget);
      expect(find.byIcon(barExtension.icon), findsOneWidget);

      await tester.pumpWidget(wrap(Builder(builder: providerScreen.buildTab)));
      expect(find.text('Provider'), findsOneWidget);
      expect(find.byIcon(providerExtension.icon), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'renders as expected',
      windowSize,
      (tester) async {
        await tester.pumpWidget(wrap(Builder(builder: fooScreen.build)));
        expect(find.byType(ExtensionView), findsOneWidget);
        expect(find.byType(EmbeddedExtensionHeader), findsOneWidget);
        expect(
          find.richTextContaining('package:foo extension'),
          findsOneWidget,
        );
        expect(find.richTextContaining('(v1.0.0)'), findsOneWidget);
        expect(find.richTextContaining('Report an issue'), findsOneWidget);
        expect(find.byType(EmbeddedExtensionView), findsOneWidget);

        await tester.pumpWidget(wrap(Builder(builder: barScreen.build)));
        expect(find.byType(ExtensionView), findsOneWidget);
        expect(find.byType(EmbeddedExtensionHeader), findsOneWidget);
        expect(
          find.richTextContaining('package:bar extension'),
          findsOneWidget,
        );
        expect(find.richTextContaining('(v2.0.0)'), findsOneWidget);
        expect(find.richTextContaining('Report an issue'), findsOneWidget);
        expect(find.byType(EmbeddedExtensionView), findsOneWidget);

        await tester.pumpWidget(wrap(Builder(builder: providerScreen.build)));
        expect(find.byType(ExtensionView), findsOneWidget);
        expect(find.byType(EmbeddedExtensionHeader), findsOneWidget);
        expect(
          find.richTextContaining('package:provider extension'),
          findsOneWidget,
        );
        expect(find.richTextContaining('(v3.0.0)'), findsOneWidget);
        expect(find.richTextContaining('Report an issue'), findsOneWidget);
        expect(find.byType(EmbeddedExtensionView), findsOneWidget);
      },
    );
  });
}
