// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/breakpoint_manager.dart';
import 'package:devtools_app/src/screens/debugger/evaluate.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpressionEvalField suggestions', () {
    late ServiceConnectionManager manager;

    setUp(() {
      final service = createMockVmServiceWrapperWithDefaults();

      manager = FakeServiceManager(service: service);
      setGlobal(ServiceConnectionManager, manager);
      setGlobal(IdeTheme, getIdeTheme());
      setGlobal(BreakpointManager, BreakpointManager());
    });

    testWidgets(
      'shows no suggestion for empty text',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, '');
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, '');
        expect(objects.searchTextEditingController.suggestionText, null);
      },
    );

    testWidgets(
      'shows "bar" item as suggestion for string "b"',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'b');
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, 'b');
        expect(objects.searchTextEditingController.suggestionText, 'ar');
      },
    );

    testWidgets(
      'shows "bazz" item as suggestion for string "baz"',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'baz');
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, 'baz');
        expect(objects.searchTextEditingController.suggestionText, 'z');
      },
    );

    testWidgets(
      'shows "foo" (first item) item as suggestion for field',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.');
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, 'someValue.');
        expect(objects.searchTextEditingController.suggestionText, 'foo');
      },
    );

    testWidgets(
      'pressing "arrowDown" shows the "bar" item as suggestion for field',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

        expect(objects.searchTextEditingController.text, 'someValue.');
        expect(objects.searchTextEditingController.suggestionText, 'bar');
      },
    );

    testWidgets(
      'pressing "arrowDown" and "arrowUp" shows the "foo" item as suggestion for field',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);

        expect(objects.searchTextEditingController.text, 'someValue.');
        expect(objects.searchTextEditingController.suggestionText, 'foo');
      },
    );

    testWidgets(
      'pressing "arrowDown" shows the "bazz" item as suggestion for string "ba"',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.ba');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

        expect(objects.searchTextEditingController.text, 'someValue.ba');
        expect(objects.searchTextEditingController.suggestionText, 'zz');
      },
    );

    testWidgets(
      'pressing "arrowDown" and "arrowUp" shows the "bar" item as suggestion for string "ba"',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.ba');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);

        expect(objects.searchTextEditingController.text, 'someValue.ba');
        expect(objects.searchTextEditingController.suggestionText, 'r');
      },
    );

    testWidgets(
      'removing the dot after a word removes the suggestion',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.');
        await tester.enterText(objects.textField, 'someValue');
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, 'someValue');
        expect(objects.searchTextEditingController.suggestionText, null);
      },
    );

    testWidgets(
      'when the cursor is not at the end of the text, don\'t show suggestion',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.');
        objects.searchTextEditingController.selection =
            const TextSelection.collapsed(offset: 0);
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, 'someValue.');
        expect(objects.searchTextEditingController.suggestionText, null);
      },
    );

    testWidgets(
      'when there is one exact match, don\'t show suggestion text',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.bazz');
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, 'someValue.bazz');
        expect(objects.searchTextEditingController.suggestionText, null);
      },
    );

    testWidgets(
      'when there is no match, don\'t show suggestion text',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.bazzz');
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, 'someValue.bazzz');
        expect(objects.searchTextEditingController.suggestionText, null);
      },
    );

    testWidgets(
      'when there is a exact match ("bar") and another match ("barz"), the exact won\'t show suggestion text',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.bar');
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, 'someValue.bar');
        expect(objects.searchTextEditingController.suggestionText, null);
      },
    );

    testWidgets(
      'when there is a exact match ("bar") and another match ("barz"), the other match will show suggestion text',
      (tester) async {
        final objects = await _setupEvalFieldObjects(tester);

        await tester.enterText(objects.textField, 'someValue.bar');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        expect(objects.searchTextEditingController.text, 'someValue.bar');
        expect(objects.searchTextEditingController.suggestionText, 'z');
      },
    );
  });
}

class _EvalFieldTestObjects {
  _EvalFieldTestObjects(this.searchTextEditingController, this.textField);

  final SearchTextEditingController searchTextEditingController;
  final Finder textField;
}

Future<_EvalFieldTestObjects> _setupEvalFieldObjects(
  WidgetTester tester,
) async {
  final debuggerController = DebuggerController(initialSwitchToIsolate: false);

  final evalField = ExpressionEvalField(
    controller: debuggerController,
    getAutoCompleteResults: (value, controller) async {
      return ['foo', 'bar', 'bazz', 'fozz', 'barz']
          // Simple implementation of search
          .where((element) => element.startsWith(value.activeWord))
          .toList();
    },
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: evalField,
      ),
    ),
  );

  final textField = find.byType(TextField).first;

  final state =
      tester.state<ExpressionEvalFieldState>(find.byWidget(evalField));

  return _EvalFieldTestObjects(state.searchTextFieldController, textField);
}
