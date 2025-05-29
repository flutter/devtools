// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/analytics/constants.dart' as gac;
import 'package:devtools_app/src/shared/editor/api_classes.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_controller.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_refactors.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_types.dart';
import 'package:devtools_app/src/standalone_ui/ide_shared/property_editor/property_editor_view.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    (document: textDocument1, position: activeCursorPosition3): resultWithText,
    (document: textDocument1, position: activeCursorPosition4): resultWithTitle,
    (document: textDocument1, position: activeCursorPosition5):
        deprecatedResult,
  };

  late MockEditorClient mockEditorClient;
  late PropertyEditorController controller;
  late PropertyEditorView propertyEditor;

  setUpAll(() {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(IdeTheme, IdeTheme());

    mockEditorClient = MockEditorClient();
    when(
      mockEditorClient.editableArgumentsApiIsRegistered,
    ).thenReturn(ValueNotifier(true));
    when(
      mockEditorClient.activeLocationChangedStream,
    ).thenAnswer((_) => eventStream);

    controller = PropertyEditorController(mockEditorClient);
    propertyEditor = PropertyEditorView(controller: controller);
  });

  group('on cursor location change', () {
    void Function()? listener;
    Completer? getEditableArgsCalled;

    Future<List<EditableArgument>> waitForEditableArgs() {
      final argsCompleter = Completer<List<EditableArgument>>();
      listener = () {
        if (!argsCompleter.isCompleted) {
          argsCompleter.complete(
            controller.editableWidgetData.value?.properties,
          );
        }
      };
      controller.editableWidgetData.addListener(listener!);
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
      getEditableArgsCalled = Completer<void>();
      for (final MapEntry(key: location, value: result)
          in locationToArgsResult.entries) {
        when(
          // ignore: discarded_futures, for mocking purposes.
          mockEditorClient.getEditableArguments(
            textDocument: location.document,
            position: location.position,
            screenId: gac.PropertyEditorSidebar.id,
          ),
        ).thenAnswer((realInvocation) {
          getEditableArgsCalled?.complete();
          getEditableArgsCalled = Completer<void>();
          return Future.value(result);
        });
      }
    });

    tearDown(() {
      if (listener != null) {
        controller.editableWidgetData.removeListener(listener!);
      }
    });

    testWidgets('initial welcome screen', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly();
      await tester.pumpAndSettle();

      // Verify the welcome message is shown.
      expect(find.textContaining(welcomeMessageText), findsOneWidget);
      expect(find.textContaining(howToUseText), findsOneWidget);
      expect(find.textContaining(exampleWidgetText), findsOneWidget);
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

    testWidgets('verify editable arguments when some are deprecated', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Load the property editor.
        await tester.pumpWidget(wrap(propertyEditor));
        final editableArgsFuture = waitForEditableArgs();

        // Send an active location changed event.
        eventController.add(activeLocationChangedEvent5);

        // Wait for the expected editable args.
        final editableArgs = await editableArgsFuture;
        verifyEditableArgs(
          actual: editableArgs,
          // Only deprecated properties with set arguments should be included.
          expected: [deprecatedPropertyWithArg],
        );
      });
    });

    testWidgets('verify editable arguments update when widget changes', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Load the property editor.
        await tester.pumpWidget(wrap(propertyEditor));

        // Send an active location changed event.
        final editableArgsFuture1 = waitForEditableArgs();
        eventController.add(activeLocationChangedEvent3);

        // Wait for the expected editable args.
        await editableArgsFuture1;
        await tester.pumpAndSettle();

        // Verify the inputs.
        final textInput = _findTextFormField('text');
        expect(textInput, findsOneWidget);
        final textValue = _textFormFieldValue(textInput, tester: tester);
        expect(textValue, equals('This is some text.'));

        // Send an active location changed event.
        final editableArgsFuture2 = waitForEditableArgs();
        eventController.add(activeLocationChangedEvent4);

        // Wait for the expected editable args.
        await editableArgsFuture2;
        await tester.pumpAndSettle();

        // Verify the inputs.
        final titleInput = _findTextFormField('title*');
        expect(titleInput, findsOneWidget);
        final titleValue = _textFormFieldValue(titleInput, tester: tester);
        expect(titleValue, equals('Hello world!'));
      });
    });

    testWidgets('verify does not fetch editable arguments for non-Dart files', (
      tester,
    ) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        await tester.pumpWidget(wrap(propertyEditor));
        final getEditableArgsCalledFuture = getEditableArgsCalled!.future;

        // Send an active location changed event.
        eventController.add(activeLocationChangedEventNotDart);

        // Verify it doesn't trigger a request to getEditableArgs.
        try {
          await getEditableArgsCalledFuture.timeout(
            const Duration(milliseconds: 100),
          );
          fail('getEditableArgs was unexpectedly called.');
        } on TimeoutException catch (e) {
          expect(e, isA<TimeoutException>());
        }

        // Verify "No Dart code" message is shown.
        await tester.pumpAndSettle();
        expect(find.textContaining(noDartCodeText), findsOneWidget);
        expect(find.textContaining(howToUseText), findsOneWidget);
        expect(find.textContaining(exampleWidgetText), findsOneWidget);
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
      controller.initForTestsOnly(editableArgsResult: result1);
      await tester.pumpAndSettle();

      final titleInput = _findTextFormField('String? title');
      final widthInput = _findTextFormField('double width');
      final heightInput = _findTextFormField('double? height');

      // Verify the inputs are expected.
      expect(_findNoPropertiesMessage, findsNothing);
      expect(titleInput, findsOneWidget);
      expect(widthInput, findsOneWidget);
      expect(heightInput, findsOneWidget);

      // Verify the labels and required are expected.
      _labelsAndRequiredTextAreExpected(
        titleInput,
        inputExpectations: titleInputExpectations,
      );
      _labelsAndRequiredTextAreExpected(
        widthInput,
        inputExpectations: widthInputExpectations,
      );
      _labelsAndRequiredTextAreExpected(
        heightInput,
        inputExpectations: heightInputExpectations,
      );
    });

    testWidgets('inputs are expected for second group of editable arguments', (
      tester,
    ) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: result2);
      await tester.pumpAndSettle();

      final softWrapInput = _findDropdownButtonFormField('bool softWrap');
      final alignInput = _findDropdownButtonFormField('Alignment? align');

      // Verify the inputs are expected.
      expect(_findNoPropertiesMessage, findsNothing);
      expect(softWrapInput, findsOneWidget);
      expect(alignInput, findsOneWidget);

      // Verify the labels and required are expected.
      _labelsAndRequiredTextAreExpected(
        softWrapInput,
        inputExpectations: softWrapInputExpectations,
      );
      _labelsAndRequiredTextAreExpected(
        alignInput,
        inputExpectations: alignInputExpectations,
      );
    });

    testWidgets('softWrap input has expected options', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: result2);
      await tester.pumpAndSettle();

      // Verify the input options are expected.
      final softWrapInput = _findDropdownButtonFormField('softWrap');
      await _verifyDropdownMenuItems(
        softWrapInput,
        menuOptions: ['true', 'false'],
        selectedOption: 'true',
        defaultOption: 'true',
        tester: tester,
      );
    });

    testWidgets('softWrap input has expected tooltip', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: result2);
      await tester.pumpAndSettle();

      // Verify the tooltip is expected.
      final softWrapInput = _findDropdownButtonFormField('softWrap');
      await _tooltipContentIsExpected(
        softWrapInput,
        tooltipContent: softWrapTooltipContent,
        tester: tester,
      );
    });

    testWidgets('align input has expected options', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: result2);
      await tester.pumpAndSettle();

      // Verify the input options are expected.
      final alignInput = _findDropdownButtonFormField('align');
      await _verifyDropdownMenuItems(
        alignInput,
        menuOptions: [
          '.bottomCenter',
          '.bottomLeft',
          '.bottomRight',
          '.center',
          '.centerLeft',
          '.centerRight',
          '.topCenter',
          '.topLeft',
          '.topRight',
        ],
        selectedOption: '.center',
        defaultOption: '.bottomLeft',
        tester: tester,
      );
    });

    testWidgets('align input has expected tooltip', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: result2);
      await tester.pumpAndSettle();

      // Verify the tooltip is expected.
      final alignInput = _findDropdownButtonFormField('align');
      await _tooltipContentIsExpected(
        alignInput,
        tooltipContent: alignTooltipContent,
        tester: tester,
      );
    });

    testWidgets('no inputs if widget has no editable properties', (
      tester,
    ) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: resultWithNoWidget);
      await tester.pumpAndSettle();

      // Verify the "No widget" message is displayed.
      expect(find.textContaining(noWidgetText), findsOneWidget);
      expect(find.textContaining(howToUseText), findsOneWidget);
      expect(find.textContaining(exampleWidgetText), findsOneWidget);
    });
  });

  group('inputs for deprecated arguments', () {
    testWidgets('inputs are expected for deprecated arguments', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: deprecatedResult);
      await tester.pumpAndSettle();

      final deprecatedWithArgInput = _findDropdownButtonFormField(
        'deprecatedWithArg',
      );

      // Verify the inputs are expected.
      expect(deprecatedWithArgInput, findsOneWidget);

      // Verify the labels and required are expected.
      _labelsAndRequiredTextAreExpected(
        deprecatedWithArgInput,
        inputExpectations: deprecatedWithArgInputExpectations,
      );
    });
  });

  group('filtering editable arguments', () {
    void resetFilters() {
      for (final filter in controller.settingFilters) {
        filter.setting.value = filter.defaultValue;
      }
    }

    tearDown(() {
      resetFilters();
    });

    testWidgets('can filter by name', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: result1);
      await tester.pumpAndSettle();

      final titleInput = _findTextFormField('String? title');
      final widthInput = _findTextFormField('double width');
      final heightInput = _findTextFormField('double? height');

      // Verify all inputs are visible.
      expect(_findNoPropertiesMessage, findsNothing);
      expect(titleInput, findsOneWidget);
      expect(widthInput, findsOneWidget);
      expect(heightInput, findsOneWidget);

      // Filter by the "width" property.
      final filterField = _findFilterField();
      expect(filterField, findsOneWidget);
      await _inputText(filterField, text: 'width', tester: tester);

      // Verify only the "width" property is visible.
      expect(widthInput, findsOneWidget);
      expect(titleInput, findsNothing);
      expect(heightInput, findsNothing);
    });

    testWidgets('can filter by type', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: result1);
      await tester.pumpAndSettle();

      final titleInput = _findTextFormField('String? title');
      final widthInput = _findTextFormField('double width');
      final heightInput = _findTextFormField('double? height');

      // Verify all inputs are visible.
      expect(_findNoPropertiesMessage, findsNothing);
      expect(titleInput, findsOneWidget);
      expect(widthInput, findsOneWidget);
      expect(heightInput, findsOneWidget);

      // Filter by the "double" type.
      final filterField = _findFilterField();
      expect(filterField, findsOneWidget);
      await _inputText(filterField, text: 'double', tester: tester);

      // Verify only the "width" and "height" properties are visible.
      expect(widthInput, findsOneWidget);
      expect(heightInput, findsOneWidget);
      expect(titleInput, findsNothing);
    });

    testWidgets('can filter by value', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: result1);
      await tester.pumpAndSettle();

      final titleInput = _findTextFormField('String? title');
      final widthInput = _findTextFormField('double width');
      final heightInput = _findTextFormField('double? height');

      // Verify all inputs are visible.
      expect(_findNoPropertiesMessage, findsNothing);
      expect(titleInput, findsOneWidget);
      expect(widthInput, findsOneWidget);
      expect(heightInput, findsOneWidget);

      // Filter by the "Hello world!" value.
      final filterField = _findFilterField();
      expect(filterField, findsOneWidget);
      await _inputText(filterField, text: 'Hello world!', tester: tester);

      // Verify only the "title" property is visible.
      expect(titleInput, findsOneWidget);
      expect(widthInput, findsNothing);
      expect(heightInput, findsNothing);
    });

    testWidgets('can filter for only set values', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the editable args.
      controller.initForTestsOnly(editableArgsResult: result1);
      await tester.pumpAndSettle();

      final titleInput = _findTextFormField('String? title');
      final widthInput = _findTextFormField('double width');
      final heightInput = _findTextFormField('double? height');

      // Verify all inputs are visible.
      expect(_findNoPropertiesMessage, findsNothing);
      expect(titleInput, findsOneWidget);
      expect(widthInput, findsOneWidget);
      expect(heightInput, findsOneWidget);

      // Filter for only set vaues.
      await _setFilter(
        'Only include properties that are set in the code.',
        tester: tester,
      );

      // Verify only the "title" and "width" properties are visible.
      expect(heightInput, findsNothing);
      expect(titleInput, findsOneWidget);
      expect(widthInput, findsOneWidget);
    });
  });

  group('editing arguments', () {
    late Completer<String> nextEditCompleter;

    // A fake argument that the server can't support.
    const fakeBogusArgument = 'fakeBogusArgument';

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
          screenId: 'propertyEditorSidebar',
        ),
      ).thenAnswer((realInvocation) {
        final calledWithArgs = realInvocation.namedArguments;
        final name = calledWithArgs[const Symbol('name')];
        final value = calledWithArgs[const Symbol('value')];
        final success = value != fakeBogusArgument;
        nextEditCompleter.complete(
          '$name: $value (TYPE: ${value?.runtimeType ?? 'null'}, SUCCESS: $success)',
        );

        return Future.value(
          GenericApiResponse(
            success: success,
            errorCode: success ? null : -32019,
          ),
        );
      });
    });

    testWidgets('editing a string input (title)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the title.
        final titleInput = _findTextFormField('title*');
        expect(titleInput, findsOneWidget);
        await _inputText(titleInput, text: 'Brand New Title!', tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(
          nextEdit,
          equals('title: Brand New Title! (TYPE: String, SUCCESS: true)'),
        );
      });
    });

    testWidgets('editing a string input to null (title)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the title.
        final titleInput = _findTextFormField('title');
        await _inputText(titleInput, text: 'null', tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('title: null (TYPE: null, SUCCESS: true)'));
      });
    });

    testWidgets('editing a string input to empty string (title)', (
      tester,
    ) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
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
            ' (TYPE: String, SUCCESS: true)',
          ),
        );
      });
    });

    testWidgets('editing a string input to an invalid parameter (title)', (
      tester,
    ) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the title.
        final titleInput = _findTextFormField('title');
        await _inputText(titleInput, text: fakeBogusArgument, tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(
          nextEdit,
          equals(
            'title: fakeBogusArgument'
            ' (TYPE: String, SUCCESS: false)',
          ),
        );

        await tester.pumpAndSettle();
        expect(
          find.textContaining('Invalid value for parameter. (Property: title)'),
          findsOneWidget,
        );
      });
    });

    testWidgets('editing a string input to its current value (title)', (
      tester,
    ) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the title.
        final titleInput = _findTextFormField('title');
        await _inputText(titleInput, text: 'Hello world!', tester: tester);

        // Verify it doesn't trigger an edit.
        try {
          await nextEditCompleter.future.timeout(
            const Duration(milliseconds: 100),
          );
          fail('nextEditCompleter was unexpectedly completed.');
        } on TimeoutException catch (e) {
          expect(e, isA<TimeoutException>());
        }
      });
    });

    testWidgets('submitting a string input with TAB (title)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the title.
        final titleInput = _findTextFormField('title*');
        expect(titleInput, findsOneWidget);
        await _inputText(
          titleInput,
          text: 'Enter with TAB!',
          tester: tester,
          inputDoneKey: LogicalKeyboardKey.tab,
        );

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(
          nextEdit,
          equals('title: Enter with TAB! (TYPE: String, SUCCESS: true)'),
        );
      });
    });

    testWidgets('editing a numeric input (height)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the height.
        final heightInput = _findTextFormField('height');
        await _inputText(heightInput, text: '55.81', tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('height: 55.81 (TYPE: double, SUCCESS: true)'));
      });
    });

    testWidgets('editing a numeric input to null (height)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the height.
        final heightInput = _findTextFormField('height');
        await _inputText(heightInput, text: '', tester: tester);

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('height: null (TYPE: null, SUCCESS: true)'));
      });
    });

    testWidgets('editing a numeric input to its default value (height)', (
      tester,
    ) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the height.
        final heightInput = _findTextFormField('height');
        await _inputText(heightInput, text: '20.0', tester: tester);

        // Verify it doesn't trigger an edit.
        try {
          await nextEditCompleter.future.timeout(
            const Duration(milliseconds: 100),
          );
          fail('nextEditCompleter was unexpectedly completed.');
        } on TimeoutException catch (e) {
          expect(e, isA<TimeoutException>());
        }
      });
    });

    testWidgets('submitting a numeric input with TAB (height)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result1);
        await tester.pumpWidget(wrap(propertyEditor));

        // Edit the height.
        final heightInput = _findTextFormField('height');
        await _inputText(
          heightInput,
          text: '63.5',
          tester: tester,
          inputDoneKey: LogicalKeyboardKey.tab,
        );

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('height: 63.5 (TYPE: double, SUCCESS: true)'));
      });
    });

    testWidgets('editing an enum input (align)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result2);
        await tester.pumpWidget(wrap(propertyEditor));

        // Select the align: Alignment.topLeft option.
        final alignInput = _findDropdownButtonFormField('align');
        await _selectDropdownMenuItem(
          alignInput,
          optionToSelect: '.topLeft',
          currentlySelected: '.center',
          tester: tester,
        );

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(
          nextEdit,
          equals('align: Alignment.topLeft (TYPE: String, SUCCESS: true)'),
        );
      });
    });

    testWidgets('editing a nullable enum input (align)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result2);
        await tester.pumpWidget(wrap(propertyEditor));

        // Select the align: null option.
        final alignInput = _findDropdownButtonFormField('align');
        await _selectDropdownMenuItem(
          alignInput,
          optionToSelect: 'null',
          currentlySelected: '.center',
          tester: tester,
        );

        // Verify the edit is expected.
        final nextEdit = await nextEditCompleter.future;
        expect(nextEdit, equals('align: null (TYPE: null, SUCCESS: true)'));
      });
    });

    testWidgets('editing a boolean input (softWrap)', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        controller.initForTestsOnly(editableArgsResult: result2);
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
        expect(nextEdit, equals('softWrap: false (TYPE: bool, SUCCESS: true)'));
      });
    });
  });

  group('refactors', () {
    void initWithRefactors(List<String> refactorNames) {
      controller.initForTestsOnly(
        document: textDocument1,
        cursorPosition: activeCursorPosition1,
        editableArgsResult: result1,
        refactors: refactorNames.map(_createCommand).toList(),
      );
    }

    setUp(() {
      FeatureFlags.propertyEditorRefactors = true;
    });

    testWidgets('main refactors are displayed in a consistent order', (
      tester,
    ) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        initWithRefactors([
          'Wrap with Row',
          'Wrap with widget...',
          'Wrap with Padding',
          'Wrap with Expanded',
          'Wrap with Container',
          'Wrap with Center',
          'Wrap with Column',
          'Wrap with SizedBox',
        ]);

        await tester.pumpWidget(wrap(propertyEditor));

        // Verify the main refactor buttons are displayed in the expected order.
        final expectedMainRefactorOrder = [
          'Widget',
          'Padding',
          'Container',
          'Column',
          'Row',
          'Center',
          'SizedBox',
        ];
        final mainRefactorButtons = tester
            .widgetList<DevToolsTooltip>(
              find.descendant(
                of: find.byType(WrapWithRefactors),
                matching: find.byType(DevToolsTooltip),
              ),
            )
            .toList();

        expect(mainRefactorButtons.length, expectedMainRefactorOrder.length);

        for (int i = 0; i < expectedMainRefactorOrder.length; i++) {
          expect(mainRefactorButtons[i].message, expectedMainRefactorOrder[i]);
        }
      });
    });

    testWidgets('shows all available refactors', (tester) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        initWithRefactors([
          'Wrap with Row',
          'Wrap with Expanded',
          'Wrap with Container',
          'Wrap with Column',
          'Wrap with SizedBox',
        ]);
        await tester.pumpWidget(wrap(propertyEditor));

        // Verify the "Wrap with:" text is displayed.
        expect(find.text('Wrap with:'), findsOneWidget);

        // Verify the expected refactors match.
        final expectedRefactors = [
          'Row',
          'Expanded',
          'Container',
          'Column',
          'SizedBox',
        ];

        // TODO: Finish test case

        // Verify the "Show more" button is displayed for other refactors.
        expect(find.text('Show more'), findsOneWidget);
      });
    });

    testWidgets('extra refactors are hidden behind "show more"', (
      tester,
    ) async {
      return await tester.runAsync(() async {
        // Load the property editor.
        initWithRefactors([
          'Wrap with Row',
          'Wrap with widget...',
          'Wrap with Padding',
          'Wrap with Expanded',
          'Wrap with Container',
          'Wrap with Center',
          'Wrap with Column',
          'Wrap with SizedBox',
          'Wrap with FutureBuilder',
          'Wrap with Flexible',
        ]);
        await tester.pumpWidget(wrap(propertyEditor));

        // Verify the "Show more" button is displayed for other refactors.
        expect(find.text('Show more'), findsOneWidget);

        // TODO: finish test case.
      });
    });
  }, skip: true);

  group('widget name and documentation', () {
    testWidgets('expanding and collapsing documentation', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the result from the server.
      controller.initForTestsOnly(
        editableArgsResult: resultWithWidgetNameAndDocs,
      );
      await tester.pumpAndSettle();

      final widgetName = find.text('MyFlutterWidget');
      final truncatedDocsFinder = find.richText('Creates a Flutter widget.');
      final expandedDocsFinder = _findDocsWithText([
        // Checks that brackets/backticks are removed.
        'Takes width and height as arguments.',
        'Example: MyWidget(title: 1.0, height: 2.0)',
      ]);
      final expandDocsButton = _findExpandDocsButton(isExpanded: false);
      final collapseDocsButton = _findExpandDocsButton(isExpanded: true);

      // Verify the documentation is collapsed.
      expect(widgetName, findsOneWidget);
      expect(truncatedDocsFinder, findsOneWidget);
      for (final finder in expandedDocsFinder) {
        expect(finder, findsNothing);
      }
      expect(expandDocsButton, findsOneWidget);
      expect(collapseDocsButton, findsNothing);

      // Expand the documentation.
      await tester.tap(expandDocsButton);
      await tester.pumpAndSettle();

      // Verify the documentation is now expanded.
      expect(widgetName, findsOneWidget);
      expect(truncatedDocsFinder, findsOneWidget);
      for (final finder in expandedDocsFinder) {
        expect(finder, findsOneWidget);
      }
      expect(expandDocsButton, findsNothing);
      expect(collapseDocsButton, findsOneWidget);
    });

    testWidgets('widget name is present but no documentation', (tester) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the result from the server.
      controller.initForTestsOnly(
        editableArgsResult: resultWithWidgetNameNoDocs,
      );
      await tester.pumpAndSettle();

      // Verify widget name and short description are present.
      final widgetName = find.text('MyFlutterWidget');
      final shortDescriptionFinder = find.richText(
        // We create a short description based on the widget name.
        'Creates a MyFlutterWidget.',
      );
      expect(widgetName, findsOneWidget);
      expect(shortDescriptionFinder, findsOneWidget);

      // Verify there is no expand/collapse button.
      final expandDocsButton = _findExpandDocsButton(isExpanded: false);
      final collapseDocsButton = _findExpandDocsButton(isExpanded: true);
      expect(expandDocsButton, findsNothing);
      expect(collapseDocsButton, findsNothing);
    });

    testWidgets('widget name and docs are present but no arguments', (
      tester,
    ) async {
      // Load the property editor.
      await tester.pumpWidget(wrap(propertyEditor));

      // Change the result from the server.
      controller.initForTestsOnly(
        editableArgsResult: resultWithWidgetNameAndDocsNoArgs,
      );
      await tester.pumpAndSettle();

      // Verify the truncated documentation is visible.
      final widgetName = find.text('MyFlutterWidget');
      final truncatedDocsFinder = find.richText('Creates a Flutter widget.');
      final expandDocsButton = _findExpandDocsButton(isExpanded: false);
      expect(widgetName, findsOneWidget);
      expect(truncatedDocsFinder, findsOneWidget);
      expect(expandDocsButton, findsOneWidget);

      // Verify the message about no editable properties is visible.
      final noEditablePropertiesMessage = find.richTextContaining(
        'MyFlutterWidget has no editable widget properties.',
      );
      expect(noEditablePropertiesMessage, findsOneWidget);
    });
  });
}

final _findNoPropertiesMessage = find.text(
  'No widget properties at current cursor location.',
);

Future<void> _setFilter(
  String filterSettingText, {
  required WidgetTester tester,
}) async {
  // Click the filter button.
  final filterButtonFinder = find.byType(DevToolsFilterButton);
  await tester.tap(filterButtonFinder);
  await tester.pumpAndSettle();

  // Find the checkbox for the filter and click it.
  final rowFinder = find.ancestor(
    of: find.textContaining(filterSettingText),
    matching: find.byType(Row),
  );
  final checkboxFinder = find.descendant(
    of: rowFinder,
    matching: find.byType(NotifierCheckbox),
  );
  await tester.tap(checkboxFinder);
  await tester.pumpAndSettle();

  // Click "Apply" to apply the filter and close the dialog.
  final applyFilterButtonFinder = find.byType(DialogApplyButton);
  await tester.tap(applyFilterButtonFinder);
  await tester.pumpAndSettle();
}

Finder _findFilterField() => find.descendant(
  of: find.byType(StandaloneFilterField<EditableProperty>),
  matching: find.byType(TextField),
);

Finder _findTextFormField(String inputName) => find.ancestor(
  of: find.richTextContaining(inputName),
  matching: find.byType(TextFormField),
);

String? _textFormFieldValue(
  Finder textFormFieldFinder, {
  required WidgetTester tester,
}) {
  final textFormFieldWidget = tester.widget<TextFormField>(textFormFieldFinder);
  return textFormFieldWidget.initialValue;
}

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

void _labelsAndRequiredTextAreExpected(
  Finder inputFinder, {
  required Map<String, bool> inputExpectations,
}) {
  // Check for the existence/non-existence of the "set" badge.
  final shouldBeSet = inputExpectations['isSet'] == true;
  expect(
    _labelForInput(inputFinder, matching: 'set'),
    shouldBeSet ? findsOneWidget : findsNothing,
    reason: 'Expected to find ${shouldBeSet ? 'a' : 'no'} "set" badge.',
  );
  // Check for the existence/non-existence of the "deprecated" badge.
  final shouldBeDeprecated = inputExpectations['isDeprecated'] == true;
  expect(
    _labelForInput(inputFinder, matching: 'deprecated'),
    shouldBeDeprecated ? findsOneWidget : findsNothing,
    reason:
        'Expected to find ${shouldBeDeprecated ? 'a' : 'no'} "deprecated" badge.',
  );
  // Check for the existence/non-existence of the "default" badge.
  final shouldBeDefault =
      inputExpectations['isDefault'] == true && !shouldBeDeprecated;
  expect(
    _labelForInput(inputFinder, matching: 'default'),
    shouldBeDefault ? findsOneWidget : findsNothing,
    reason: 'Expected to find ${shouldBeDefault ? 'a' : 'no'} "default" badge.',
  );
  // Check for the existence/non-existence of the required text ('*').
  final shouldBeRequired = inputExpectations['isRequired'] == true;
  expect(
    _requiredTextForInput(inputFinder),
    shouldBeRequired ? findsOneWidget : findsNothing,
    reason:
        'Expected to find ${shouldBeRequired ? 'the' : 'no'} "required" indicator.',
  );
}

Future<void> _tooltipContentIsExpected(
  Finder inputFinder, {
  required String tooltipContent,
  required WidgetTester tester,
}) async {
  final inputRowFinder = find.ancestor(
    of: inputFinder,
    matching: find.byType(Row),
  );
  final iconFinder = find.descendant(
    of: inputRowFinder,
    matching: find.byIcon(Icons.info_outline),
  );

  // Verify tooltip is not visible.
  expect(find.text(tooltipContent), findsNothing);

  // Simulate a hover for 600 ms.
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.moveTo(tester.getRect(iconFinder).center);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();

  // Verify tooltip is visible with expected content.
  expect(find.text(tooltipContent), findsOneWidget);

  // Clean-up, remove gesture pointer.
  await gesture.removePointer();
}

Finder _helperTextForInput(Finder inputFinder, {required String matching}) {
  final rowFinder = find.ancestor(of: inputFinder, matching: find.byType(Row));
  return find.descendant(of: rowFinder, matching: find.richText(matching));
}

Finder _findDropdownButtonFormField(String inputName) => find.ancestor(
  of: find.richTextContaining(inputName),
  matching: find.byType(DropdownButtonFormField),
);

List<Finder> _findDocsWithText(List<String> paragraphs) =>
    paragraphs.map((paragraph) => find.richTextContaining(paragraph)).toList();

Finder _findExpandDocsButton({required bool isExpanded}) =>
    find.text(isExpanded ? 'Show less' : 'Show more');

Future<void> _verifyDropdownMenuItems(
  Finder dropdownButton, {
  required List<String> menuOptions,
  required String selectedOption,
  required WidgetTester tester,
  String? defaultOption,
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
    // Verify the default value has a label.
    if (menuOptionValue == defaultOption) {
      final defaultLabelFinder = find.descendant(
        of: menuOptionFinder,
        matching: find.descendant(
          of: find.byType(RoundedLabel),
          matching: find.text('D'),
        ),
      );
      expect(defaultLabelFinder, findsOneWidget);
    }
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
  LogicalKeyboardKey? inputDoneKey,
}) async {
  await tester.enterText(textFormField, text);
  if (inputDoneKey != null) {
    await tester.sendKeyDownEvent(inputDoneKey);
  } else {
    await tester.testTextInput.receiveAction(TextInputAction.done);
  }
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

// Location position 3
final activeCursorPosition3 = CursorPosition(character: 55, line: 2);
final anchorCursorPosition3 = CursorPosition(character: 60, line: 4);
final editorSelection3 = EditorSelection(
  active: activeCursorPosition3,
  anchor: anchorCursorPosition3,
);
final activeLocationChangedEvent3 = ActiveLocationChangedEvent(
  selections: [editorSelection3],
  textDocument: textDocument1,
);

// Location position 4
final activeCursorPosition4 = CursorPosition(character: 10, line: 11);
final anchorCursorPosition4 = CursorPosition(character: 12, line: 2);
final editorSelection4 = EditorSelection(
  active: activeCursorPosition4,
  anchor: anchorCursorPosition4,
);
final activeLocationChangedEvent4 = ActiveLocationChangedEvent(
  selections: [editorSelection4],
  textDocument: textDocument1,
);

// Location position 5
final activeCursorPosition5 = CursorPosition(character: 81, line: 19);
final anchorCursorPosition5 = CursorPosition(character: 113, line: 12);
final editorSelection5 = EditorSelection(
  active: activeCursorPosition5,
  anchor: anchorCursorPosition5,
);
final activeLocationChangedEvent5 = ActiveLocationChangedEvent(
  selections: [editorSelection5],
  textDocument: textDocument1,
);

final notADartDocument = TextDocument(
  uriAsString: '/my/fake/other.js',
  version: 1,
);
final activeLocationChangedEventNotDart = ActiveLocationChangedEvent(
  selections: [editorSelection1],
  textDocument: notADartDocument,
);

// Widget name and documentation
const widgetName = 'MyFlutterWidget';

const dartDocText = '''
Creates a Flutter widget.

Takes [width] and [height] as arguments.

Example: `MyWidget(title: 1.0, height: 2.0)`
''';

// Result 1
final titleProperty = EditableArgument.fromJson({
  'name': 'title',
  'value': 'Hello world!',
  'type': 'string',
  'isEditable': true,
  'isNullable': true,
  'isRequired': true,
  'hasArgument': true,
});
final titleInputExpectations = {
  'isSet': true,
  'isRequired': true,
  'isDefault': false,
};

final widthProperty = EditableArgument.fromJson({
  'name': 'width',
  'displayValue': 'myWidth',
  'type': 'double',
  'errorText': 'Some reason why this can\'t be edited.',
  'isNullable': false,
  'isRequired': false,
  'hasArgument': true,
});
final widthInputExpectations = {
  'isSet': true,
  'isRequired': false,
  'isDefault': false,
};

final heightProperty = EditableArgument.fromJson({
  'name': 'height',
  'type': 'double',
  'hasArgument': false,
  'isEditable': true,
  'isNullable': true,
  'defaultValue': 20.0,
  'isRequired': false,
});
final heightInputExpectations = {
  'isSet': false,
  'isRequired': false,
  'isDefault': true,
  'isDeprecated': false,
};
final result1 = EditableArgumentsResult(
  name: widgetName,
  documentation: dartDocText,
  args: [titleProperty, widthProperty, heightProperty],
);

// Result 2
const softWrapDocumentation = '''
Whether or not the text should wrap.

If null, the default value is platform dependent. On [TargetPlatform.android],
the default is true. On [TargetPlatform.iOS], false. The remaining platforms
also default to false.
''';

final softWrapProperty = EditableArgument.fromJson({
  'name': 'softWrap',
  'type': 'bool',
  'isNullable': false,
  'defaultValue': true,
  'hasArgument': false,
  'isEditable': true,
  'isRequired': false,
  'documentation': softWrapDocumentation,
});
final softWrapInputExpectations = {
  'isSet': false,
  'isRequired': false,
  'isDefault': true,
  'isDeprecated': false,
};
const softWrapTooltipContent = '''
bool softWrap

Default value: true

Documentation:
Whether or not the text should wrap.

If null, the default value is platform dependent. On TargetPlatform.android,
the default is true. On TargetPlatform.iOS, false. The remaining platforms
also default to false.
''';

const alignDocumentation = '''
How to align the child.

The x and y values of the [Alignment] control the horizontal and vertical
alignment, respectively. 
''';
final alignProperty = EditableArgument.fromJson({
  'name': 'align',
  'type': 'enum',
  'isNullable': true,
  'hasArgument': true,
  'defaultValue': 'Alignment.bottomLeft',
  'isRequired': false,
  'isEditable': true,
  'value': 'Alignment.center',
  'documentation': alignDocumentation,
  'options': [
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
});
final alignInputExpectations = {
  'isSet': true,
  'isRequired': false,
  'isDefault': false,
  'isDeprecated': false,
};
const alignTooltipContent = '''
Alignment? align

Default value: Alignment.bottomLeft

Documentation:
How to align the child.

The x and y values of the Alignment control the horizontal and vertical
alignment, respectively. 
''';

final result2 = EditableArgumentsResult(
  name: widgetName,
  args: [softWrapProperty, alignProperty],
);

// Result for test cases of deprecated properties
final deprecatedPropertyNoArg = EditableArgument.fromJson({
  'name': 'deprecatedNoArg',
  'type': 'bool',
  'isNullable': false,
  'defaultValue': false,
  'hasArgument': false,
  'isEditable': true,
  'isRequired': false,
  'isDeprecated': true,
});

final deprecatedPropertyWithArg = EditableArgument.fromJson({
  'name': 'deprecatedWithArg',
  'type': 'bool',
  'value': false,
  'isNullable': false,
  'defaultValue': true,
  'hasArgument': true,
  'isEditable': true,
  'isRequired': false,
  'isDeprecated': true,
});

final deprecatedWithArgInputExpectations = {
  'isSet': true,
  'isRequired': false,
  'isDefault': false,
  'isDeprecated': true,
};

final deprecatedResult = EditableArgumentsResult(
  name: widgetName,
  args: [deprecatedPropertyNoArg, deprecatedPropertyWithArg],
);

// Example results for documentation test cases.
final resultWithWidgetNameAndDocs = result1;
final resultWithWidgetNameNoDocs = result2;
final resultWithWidgetNameAndDocsNoArgs = EditableArgumentsResult(
  name: widgetName,
  documentation: dartDocText,
  args: [],
);

// Example results for text input state change test cases.
final textProperty = EditableArgument.fromJson({
  'name': 'text',
  'value': 'This is some text.',
  'type': 'string',
  'isEditable': true,
  'isNullable': true,
  'isRequired': false,
  'hasArgument': true,
});
final resultWithText = EditableArgumentsResult(
  name: 'WidgetWithText',
  args: [textProperty],
);
final resultWithTitle = EditableArgumentsResult(
  name: 'WidgetWithTitle',
  args: [titleProperty],
);
final resultWithNoWidget = EditableArgumentsResult(args: []);

const welcomeMessageText = 'Welcome to the Flutter Property Editor!';
const howToUseText =
    'Please move your cursor anywhere inside a Flutter widget constructor invocation to view and edit its properties.';
const exampleWidgetText =
    'For example, the highlighted code below is a constructor invocation of a Text widget:';
const noDartCodeText = 'No Dart code found at the current cursor location.';
const noWidgetText = 'No Flutter widget found at the current cursor location.';

const _documentUri = 'file:///Users/me/flutter_app/lib/main.dart';
const _documentVersion = 1;
const _cursorLine = 10;
const _cursorChar = 20;
const commandArg =
    '''
[
  {
    "textDocument": {
      "uri": "$_documentUri",
      "version": $_documentVersion
    },
    "range": {
      "end": {
        "character": $_cursorChar,
        "line": $_cursorLine
      },
      "start": {
        "character": $_cursorChar,
        "line": $_cursorLine
      }
    },
    "kind": "refactor.flutter.wrap.generic",
    "loggedAction": "dart.assist.flutter.wrap.generic"
  }
]
''';

CodeActionCommand _createCommand(String title) => CodeActionCommand(
  command: 'dart.edit.codeAction.apply',
  args: json.decode(commandArg),
  title: title,
);
