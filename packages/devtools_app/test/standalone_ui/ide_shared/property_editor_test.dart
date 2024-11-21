// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_sidebar.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const propertyEditor = PropertyEditorSidebar();

  group('Property Editor input types', () {
    setUpAll(() {
      setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
      setGlobal(IdeTheme, IdeTheme());
    });

    testWidgets('string input', (tester) async {
      await tester.pumpWidget(wrap(propertyEditor));

      final stringInput = _findTextFormField('title');

      expect(stringInput, findsOneWidget);
    });

    testWidgets('double input', (tester) async {
      await tester.pumpWidget(wrap(propertyEditor));

      final doubleInput = _findTextFormField('width');

      expect(doubleInput, findsOneWidget);
    });

    testWidgets('bool input', (tester) async {
      await tester.pumpWidget(wrap(propertyEditor));

      final boolInput = _findDropdownButtonFormField('softWrap');

      expect(boolInput, findsOneWidget);
      await _verifyDropdownMenuItems(
        boolInput,
        menuOptions: ['true', 'false'],
        selectedOption: 'true',
        tester: tester,
      );
    });

    testWidgets('enum input', (tester) async {
      await tester.pumpWidget(wrap(propertyEditor));

      final enumInput = _findDropdownButtonFormField('align');

      expect(enumInput, findsOneWidget);
      await _verifyDropdownMenuItems(
        enumInput,
        menuOptions: [
          'Alignment.bottomCenter',
          'Alignment.bottomLeft',
          'Alignment.bottomRight',
          'Alignment.center',
          'Alignment.centerLeft',
          'Alignment.centerRight',
          'Alignment.topCenter',
          'Alignment.topLeft',
          'Alignment.topRight',
        ],
        selectedOption: 'Alignment.center',
        tester: tester,
      );
    });
  });
}

Finder _findTextFormField(String inputName) => find.ancestor(
      of: find.text(inputName),
      matching: find.byType(TextFormField),
    );

Finder _findDropdownButtonFormField(String inputName) => find.ancestor(
      of: find.text(inputName),
      matching: find.byType(DropdownButtonFormField<String>),
    );

Future<void> _verifyDropdownMenuItems(
  Finder dropdownButton, {
  required List<String> menuOptions,
  required String selectedOption,
  required WidgetTester tester,
}) async {
  // Click button to open the options.
  await tester.tap(dropdownButton);
  await tester.pumpAndSettle();

  // Verify the options are expected.
  for (final menuOptionValue in menuOptions) {
    final menuOptionFinder = find.ancestor(
      of: find.text(menuOptionValue),
      matching: find.byType(DropdownMenuItem<String>),
    );
    if (menuOptionValue == selectedOption) {
      // Flutter renders twoo menu options for the selected option.
      expect(menuOptionFinder, findsNWidgets(2));
    } else {
      expect(menuOptionFinder, findsOneWidget);
    }
  }
}
