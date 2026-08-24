// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/screens/inspector/inspector_controller.dart';
import 'package:devtools_app/src/screens/inspector/widget_properties/properties_view.dart';
import 'package:devtools_app/src/shared/diagnostics/primitives/source_location.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:mockito/mockito.dart';

void main() {
  setUp(() {
    setGlobal(IdeTheme, IdeTheme());
  });

  Widget wrapTrailing(Widget child) {
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
    final controller = _TestInspectorController();
    addTearDown(controller.dispose);

    final location = InspectorSourceLocation({
      'file': 'file:///Users/prismo/flutter_app/lib/main.dart',
      'line': 109,
      'column': 23,
    }, null);
    controller.setProperties((
      widgetProperties: const [],
      renderProperties: const [],
      layoutProperties: null,
      creationLocation: location,
    ));

    await tester.pumpWidget(
      wrapTrailing(WidgetCreationLocationTrailing(controller: controller)),
    );

    expect(find.byType(RichText), findsOneWidget);
    final richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.text.toPlainText(), 'main.dart:109:23');
  });

  testWidgets('tooltip includes the full file URI', (
    WidgetTester tester,
  ) async {
    final controller = _TestInspectorController();
    addTearDown(controller.dispose);

    final location = InspectorSourceLocation({
      'file': 'file:///Users/prismo/flutter_app/lib/main.dart',
      'line': 109,
      'column': 23,
    }, null);
    controller.setProperties((
      widgetProperties: const [],
      renderProperties: const [],
      layoutProperties: null,
      creationLocation: location,
    ));

    await tester.pumpWidget(
      wrapTrailing(WidgetCreationLocationTrailing(controller: controller)),
    );

    final tooltip =
        tester.widget(find.byType(DevToolsTooltip)) as DevToolsTooltip;
    expect(
      tooltip.message,
      'file:///Users/prismo/flutter_app/lib/main.dart:109:23',
    );
  });

  testWidgets('hides when creation location is unavailable', (
    WidgetTester tester,
  ) async {
    final controller = _TestInspectorController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapTrailing(WidgetCreationLocationTrailing(controller: controller)),
    );

    expect(find.byType(RichText), findsNothing);
  });
}

class _TestInspectorController extends Fake implements InspectorController {
  final _selectedNodeProperties = ValueNotifier<WidgetTreeNodeProperties>((
    widgetProperties: const [],
    renderProperties: const [],
    layoutProperties: null,
    creationLocation: null,
  ));

  @override
  ValueListenable<WidgetTreeNodeProperties> get selectedNodeProperties =>
      _selectedNodeProperties;

  void setProperties(WidgetTreeNodeProperties properties) {
    _selectedNodeProperties.value = properties;
  }

  void dispose() {
    _selectedNodeProperties.dispose();
  }
}
