// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/screens/inspector/widget_properties/properties_view.dart';
import 'package:devtools_app/src/shared/diagnostics/primitives/source_location.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setGlobal(IdeTheme, IdeTheme());
  });

  Widget wrapHeader(Widget child) {
    return MaterialApp(
      theme: themeFor(
        isDarkTheme: false,
        ideTheme: IdeTheme(),
        theme: ThemeData(useMaterial3: true, colorScheme: lightColorScheme),
      ),
      home: Scaffold(body: child),
    );
  }

  testWidgets('shows file name with line and column', (
    WidgetTester tester,
  ) async {
    final location = InspectorSourceLocation({
      'file': 'file:///Users/prismo/flutter_app/lib/main.dart',
      'line': 109,
      'column': 23,
    }, null);

    await tester.pumpWidget(
      wrapHeader(WidgetCreationLocationHeader(location: location)),
    );

    expect(find.text('main.dart:109:23'), findsOneWidget);
  });

  testWidgets('tooltip includes the full file URI', (
    WidgetTester tester,
  ) async {
    final location = InspectorSourceLocation({
      'file': 'file:///Users/prismo/flutter_app/lib/main.dart',
      'line': 109,
      'column': 23,
    }, null);

    await tester.pumpWidget(
      wrapHeader(WidgetCreationLocationHeader(location: location)),
    );

    final tooltip =
        tester.widget(find.byType(DevToolsTooltip)) as DevToolsTooltip;
    expect(
      tooltip.message,
      'file:///Users/prismo/flutter_app/lib/main.dart:109:23',
    );
  });
}
