// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/editor/api_classes.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_controller.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_view.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

typedef Location = ({TextDocument document, CursorPosition position});
typedef LocationToArgsResult = Map<Location, EditableArgumentsResult>;

void main() {
  final eventController = StreamController<ActiveLocationChangedEvent>();
  final eventStream = eventController.stream;

  final LocationToArgsResult locationToArgsResult = {
    (document: textDocument1, position: activeCursorPosition1): result1,
    (document: textDocument2, position: activeCursorPosition2): result2,
  };

  late MockEditorClient mockEditorClient;
  late PropertyEditorController controller;
  late PropertyEditorView propertyEditor;

  setUpAll(() {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(IdeTheme, IdeTheme());

    mockEditorClient = MockEditorClient();
    when(
      mockEditorClient.editArgumentMethodName,
    ).thenReturn(ValueNotifier(LspMethod.editArgument.methodName));
    when(
      mockEditorClient.editableArgumentsMethodName,
    ).thenReturn(ValueNotifier(LspMethod.editableArguments.methodName));
    when(
      mockEditorClient.activeLocationChangedStream,
    ).thenAnswer((_) => eventStream);

    controller = PropertyEditorController(mockEditorClient);
    propertyEditor = PropertyEditorView(controller: controller);
  });

  group('on cursor location change', () {
    void Function()? listener;

    Future<List<EditableArgument>> waitForEditableArgs() {
      final argsCompleter = Completer<List<EditableArgument>>();
      listener = () {
        argsCompleter.complete(controller.editableArgs.value);
      };
      controller.editableArgs.addListener(listener!);
      return argsCompleter.future;
    }

    void verifyEditableArgs({
      required List<EditableArgument> actual,
      required List<EditableArgument> expected,
    }) {
      final actualArgNames = actual.map((arg) => arg.name).toList();
      final expectedArgNames = expected.map((arg) => arg.name).toList();

      expect(
        collectionEquals(actualArgNames, expectedArgNames),
        isTrue,
        reason:
            'Expected ${expectedArgNames.join(', ')} not ${actualArgNames.join(', ')}',
      );
    }

    setUp(() {
      for (final MapEntry(key: location, value: result)
          in locationToArgsResult.entries) {
        when(
          // ignore: discarded_futures, for mocking purposes.
          mockEditorClient.getEditableArguments(
            textDocument: location.document,
            position: location.position,
          ),
        ).thenAnswer((realInvocation) => Future.value(result));
      }
    });

    tearDown(() {
      if (listener != null) {
        controller.editableArgs.removeListener(listener!);
      }
    });

    testWidgets('verify editable arguments for first cursor location', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Load the property editor.
        await tester.pumpWidget(wrap(propertyEditor));
        final editableArgsFuture = waitForEditableArgs();

        // Send an active location changed event.
        eventController.add(activeLocationChangedEvent1);

        // Wait for the expected editable args.
        final editableArgs = await editableArgsFuture;
        verifyEditableArgs(actual: editableArgs, expected: result1.args);
      });
    });

    testWidgets('verify editable arguments for second cursor location', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Load the property editor.
        await tester.pumpWidget(wrap(propertyEditor));
        final editableArgsFuture = waitForEditableArgs();

        // Send an active location changed event.
        eventController.add(activeLocationChangedEvent2);

        // Wait for the expected editable args.
        final editableArgs = await editableArgsFuture;
        verifyEditableArgs(actual: editableArgs, expected: result2.args);
      });
    });
  });

  group('inputs for editable arguments', () {
    testWidgets('inputs are expected for first group of editable arguments', (
      tester,
    ) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgs: result1.args);
      await tester.pumpAndSettle();

      final titleInput = _findTextFormField('title');
      final widthInput = _findTextFormField('width');
      final heightInput = _findTextFormField('height');

      // Verify the inputs are expected.
      expect(_findNoPropertiesMessage, findsNothing);
      expect(titleInput, findsOneWidget);
      expect(widthInput, findsOneWidget);
      expect(heightInput, findsOneWidget);

      // Verify the labels are expected.
      expect(_labelForInput(titleInput, matching: 'set'), findsNothing);
      expect(_labelForInput(titleInput, matching: 'default'), findsNothing);
      expect(_labelForInput(widthInput, matching: 'set'), findsNothing);
      expect(_labelForInput(widthInput, matching: 'default'), findsNothing);
      expect(_labelForInput(heightInput, matching: 'set'), findsNothing);
      expect(_labelForInput(heightInput, matching: 'default'), findsOneWidget);

      // Verify required comments exist.
      expect(_requiredTextForInput(titleInput), findsOneWidget);
    });

    testWidgets('inputs are expected for second group of editable arguments', (
      tester,
    ) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgs: result2.args);
      await tester.pumpAndSettle();

      final softWrapInput = _findDropdownButtonFormField('softWrap');
      final alignInput = _findDropdownButtonFormField('align');

      // Verify the inputs are expected.
      expect(_findNoPropertiesMessage, findsNothing);
      expect(softWrapInput, findsOneWidget);
      expect(alignInput, findsOneWidget);

      // Verify the labels are expected.
      expect(_labelForInput(softWrapInput, matching: 'set'), findsNothing);
      expect(
        _labelForInput(softWrapInput, matching: 'default'),
        findsOneWidget,
      );
      expect(_labelForInput(alignInput, matching: 'set'), findsOneWidget);
      expect(_labelForInput(alignInput, matching: 'default'), findsNothing);
    });

    testWidgets('softWrap input has expected options', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgs: result2.args);
      await tester.pumpAndSettle();

      // Verify the input options are expected.
      final softWrapInput = _findDropdownButtonFormField('softWrap');
      await _verifyDropdownMenuItems(
        softWrapInput,
        menuOptions: ['true', 'false'],
        selectedOption: 'true',
        tester: tester,
      );
    });

    testWidgets('align input has expected options', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgs: result2.args);
      await tester.pumpAndSettle();

      // Verify the input options are expected.
      final alignInput = _findDropdownButtonFormField('align');
      await _verifyDropdownMenuItems(
        alignInput,
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

  group('editing arguments', () {
    late Completer<String> nextEditCompleter;

    setUp(() {
      controller.initForTestsOnly(
        document: textDocument1,
        cursorPosition: activeCursorPosition1,
      );

      nextEditCompleter = Completer<String>();
      when(
        // ignore: discarded_futures, for mocking purposes.
        mockEditorClient.editArgument(
          textDocument: argThat(isNotNull, named: 'textDocument'),
          position: argThat(isNotNull, named: 'position'),
          name: argThat(isNotNull, named: 'name'),
          value: argThat(anything, named: 'value'),
        ),
      ).thenAnswer((realInvocation) {
        final calledWithArgs = realInvocation.namedArguments;
        final name = calledWithArgs[const Symbol('name')];
        final value = calledWithArgs[const Symbol('value')];
        nextEditCompleter.complete(
          '$name: $value (TYPE: ${value?.runtimeType ?? 'null'})',
        );
        return Future.value();
      });
    });

    testWidgets('editing a string input (title)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgs: result1.args);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the title.
        final titleInput = _findTextFormField('title*');
        expect(titleInput, findsOneWidget);
        await _inputText(titleInput, text: 'Brand New Title!', tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('title: Brand New Title! (TYPE: String)'));
      });
    });

    testWidgets('editing a string input to null (title)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgs: result1.args);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the title.
        final titleInput = _findTextFormField('title');
        await _inputText(titleInput, text: 'null', tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('title: null (TYPE: null)'));
      });
    });

    testWidgets('editing a string input to empty string (title)', (
      tester,
    ) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgs: result1.args);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the title.
        final titleInput = _findTextFormField('title');
        await _inputText(titleInput, text: '', tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(
          nextEdit,
          equals(
            'title: '
            ' (TYPE: String)',
          ),
        );
      });
    });

    testWidgets('editing a numeric input (height)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgs: result1.args);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the height.
        final heightInput = _findTextFormField('height');
        await _inputText(heightInput, text: '55.81', tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('height: 55.81 (TYPE: double)'));
      });
    });

    testWidgets('editing a numeric input to null (height)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgs: result1.args);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the height.
        final heightInput = _findTextFormField('height');
        await _inputText(heightInput, text: '', tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('height: null (TYPE: null)'));
      });
    });

    testWidgets('editing an enum input (align)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgs: result2.args);
        await tester.pumpWidget(wrap(propertyEditor));

        // Select the align: Alignment.topLeft option.
        final alignInput = _findDropdownButtonFormField('align');
        await _selectDropdownMenuItem(
          alignInput,
          optionToSelect: 'Alignment.topLeft',
          currentlySelected: 'Alignment.center',
          tester: tester,
        );

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('align: Alignment.topLeft (TYPE: String)'));
      });
    });

    testWidgets('editing a nullable enum input (align)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgs: result2.args);
        await tester.pumpWidget(wrap(propertyEditor));

        // Select the align: null option.
        final alignInput = _findDropdownButtonFormField('align');
        await _selectDropdownMenuItem(
          alignInput,
          optionToSelect: 'null',
          currentlySelected: 'Alignment.center',
          tester: tester,
        );

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('align: null (TYPE: null)'));
      });
    });

    testWidgets('editing a boolean input (softWrap)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgs: result2.args);
        await tester.pumpWidget(wrap(propertyEditor));

        // Select the softWrap: false option.
        final softWrapInput = _findDropdownButtonFormField('softWrap');
        await _selectDropdownMenuItem(
          softWrapInput,
          optionToSelect: 'false',
          currentlySelected: 'true',
          tester: tester,
        );

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('softWrap: false (TYPE: bool)'));
      });
    });
  });
}

final _findNoPropertiesMessage = find.text(
  'No widget properties at current cursor location.',
);

Finder _findTextFormField(String inputName) => find.ancestor(
  of: find.textContaining(inputName),
  matching: find.byType(TextFormField),
);

Finder _labelForInput(Finder inputFinder, {required String matching}) {
  final rowFinder = find.ancestor(of: inputFinder, matching: find.byType(Row));
  final labelFinder = find.descendant(
    of: rowFinder,
    matching: find.byType(RoundedLabel),
  );
  return find.descendant(of: labelFinder, matching: find.text(matching));
}

Finder _requiredTextForInput(Finder inputFinder) =>
    _helperTextForInput(inputFinder, matching: '*required');

Finder _helperTextForInput(Finder inputFinder, {required String matching}) {
  final rowFinder = find.ancestor(of: inputFinder, matching: find.byType(Row));
  return find.descendant(of: rowFinder, matching: find.richText(matching));
}

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
      // Flutter renders two menu options for the selected option.
      expect(menuOptionFinder, findsNWidgets(2));
    } else {
      expect(menuOptionFinder, findsOneWidget);
    }
  }
}

Future<void> _selectDropdownMenuItem(
  Finder dropdownButton, {
  required String optionToSelect,
  required String currentlySelected,
  required WidgetTester tester,
}) async {
  final optionToSelectFinder = find.descendant(
    of: find.byType(DropdownMenuItem<String>),
    matching: find.text(optionToSelect),
  );
  final currentlySelectedFinder = find.descendant(
    of: find.byType(DropdownMenuItem<String>),
    matching: find.text(currentlySelected),
  );

  // Verify the option is not yet selected.
  expect(currentlySelectedFinder, findsOneWidget);
  expect(optionToSelectFinder, findsNothing);

  // Click button to open the options.
  await tester.tap(dropdownButton);
  await tester.pumpAndSettle();

  // Click on the option.
  expect(optionToSelectFinder, findsOneWidget);
  await tester.tap(optionToSelectFinder);
  await tester.pumpAndSettle();

  // Verify the option is now selected.
  expect(currentlySelectedFinder, findsNothing);
  expect(optionToSelectFinder, findsOneWidget);
}

Future<void> _inputText(
  Finder textFormField, {
  required String text,
  required WidgetTester tester,
}) async {
  await tester.enterText(textFormField, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

// Location position 1
final activeCursorPosition1 = CursorPosition(character: 10, line: 20);
final anchorCursorPosition1 = CursorPosition(character: 12, line: 7);
final editorSelection1 = EditorSelection(
  active: activeCursorPosition1,
  anchor: anchorCursorPosition1,
);
final textDocument1 = TextDocument(
  uriAsString: '/my/fake/file.dart',
  version: 1,
);
final activeLocationChangedEvent1 = ActiveLocationChangedEvent(
  selections: [editorSelection1],
  textDocument: textDocument1,
);

// Location position 2
final activeCursorPosition2 = CursorPosition(character: 18, line: 6);
final anchorCursorPosition2 = CursorPosition(character: 22, line: 9);
final editorSelection2 = EditorSelection(
  active: activeCursorPosition2,
  anchor: anchorCursorPosition2,
);
final textDocument2 = TextDocument(
  uriAsString: '/my/fake/other.dart',
  version: 1,
);
final activeLocationChangedEvent2 = ActiveLocationChangedEvent(
  selections: [editorSelection2],
  textDocument: textDocument2,
);

// Result 1
final titleProperty = EditableArgument(
  name: 'title',
  value: 'Hello world!',
  type: 'string',
  isDefault: false,
  isEditable: true,
  isNullable: true,
  isRequired: true,
  hasArgument: false,
);
final widthProperty = EditableArgument(
  name: 'width',
  displayValue: '100.0',
  type: 'double',
  isEditable: false,
  isDefault: false,
  errorText: 'Some reason for why this can\'t be edited.',
  isNullable: false,
  value: 20.0,
  isRequired: false,
  hasArgument: false,
);
final heightProperty = EditableArgument(
  name: 'height',
  type: 'double',
  hasArgument: false,
  isEditable: true,
  isNullable: true,
  value: 20.0,
  isDefault: true,
  isRequired: false,
);
final result1 = EditableArgumentsResult(
  args: [titleProperty, widthProperty, heightProperty],
);

// Result 2
final softWrapProperty = EditableArgument(
  name: 'softWrap',
  type: 'bool',
  isNullable: false,
  value: true,
  isDefault: true,
  hasArgument: false,
  isEditable: true,
  isRequired: false,
);
final alignProperty = EditableArgument(
  name: 'align',
  type: 'enum',
  isNullable: true,
  hasArgument: true,
  isDefault: false,
  isRequired: false,
  isEditable: true,
  value: 'Alignment.center',
  options: [
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
);
final result2 = EditableArgumentsResult(
  args: [softWrapProperty, alignProperty],
);
