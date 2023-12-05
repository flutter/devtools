// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/editable_list.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/utils/test_utils.dart';

void main() {
  const windowSize = Size(1000.0, 1000.0);
  const label = 'This is the EditableList label';
  ListValueNotifier<String> entries([
    List<String> values = const <String>[],
  ]) {
    return ListValueNotifier<String>(values);
  }

  setGlobal(IdeTheme, getIdeTheme());
  setGlobal(NotificationService, NotificationService());

  group('EditableList', () {
    testWidgetsWithWindowSize(
      'shows the label',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapSimple(
            EditableList(
              entries: entries([]),
              textFieldLabel: label,
              gaRefreshSelection: '',
              gaScreen: '',
            ),
          ),
        );
        expect(find.text(label), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'triggers add',
      windowSize,
      (WidgetTester tester) async {
        const valueToAdd = 'this is the value that will be added';
        String? entryThatWasRequestedForAdd;
        final widget = EditableList(
          entries: entries(),
          textFieldLabel: label,
          onEntryAdded: (e) {
            entryThatWasRequestedForAdd = e;
          },
          gaRefreshSelection: '',
          gaScreen: '',
        );
        await tester.pumpWidget(
          wrapSimple(widget),
        );

        final actionBar = find.byType(EditableListActionBar);
        final textField = find.descendant(
          of: actionBar,
          matching: find.byType(TextField),
        );
        final addEntryButton = find.descendant(
          of: actionBar,
          matching: find.text('Add'),
        );
        await tester.enterText(textField, valueToAdd);
        await tester.tap(addEntryButton);
        await tester.pump();

        expect(entryThatWasRequestedForAdd, equals(valueToAdd));
      },
    );

    testWidgetsWithWindowSize(
      'triggers refresh',
      windowSize,
      (WidgetTester tester) async {
        var refreshWasCalled = false;
        final widget = EditableList(
          entries: entries(),
          textFieldLabel: label,
          onRefreshTriggered: () {
            refreshWasCalled = true;
          },
          gaRefreshSelection: '',
          gaScreen: '',
        );
        await tester.pumpWidget(
          wrapSimple(widget),
        );
        final refreshButton = find.byType(RefreshButton);

        await tester.tap(refreshButton);
        await tester.pump();

        expect(refreshWasCalled, isTrue);
      },
    );

    testWidgetsWithWindowSize(
      'triggers remove',
      windowSize,
      (WidgetTester tester) async {
        const valueToRemove = 'this is the value that will be removed';
        String? entryThatWasRemoved;
        final widget = EditableList(
          entries: entries([valueToRemove]),
          textFieldLabel: label,
          onEntryRemoved: (e) {
            entryThatWasRemoved = e;
          },
          gaRefreshSelection: '',
          gaScreen: '',
        );
        await tester.pumpWidget(
          wrapSimple(widget),
        );
        final removeButton = find.byType(EditableListRemoveDirectoryButton);

        await tester.tap(removeButton);
        await tester.pump();

        expect(entryThatWasRemoved, equals(valueToRemove));
      },
    );

    testWidgetsWithWindowSize(
      'copies an entry',
      windowSize,
      (WidgetTester tester) async {
        String? clipboardContents;
        setupClipboardCopyListener(
          clipboardContentsCallback: (contents) {
            clipboardContents = contents ?? '';
          },
        );
        const valueToCopy = 'this is the value that will be copied';
        final widget = EditableList(
          entries: entries([valueToCopy]),
          textFieldLabel: label,
          gaRefreshSelection: '',
          gaScreen: '',
        );
        await tester.pumpWidget(
          wrapSimple(widget),
        );
        final copyButton = find.byType(EditableListCopyDirectoryButton);

        await tester.tap(copyButton);
        await tester.pump();

        expect(clipboardContents, equals(valueToCopy));
      },
    );

    group('defaults', () {
      testWidgetsWithWindowSize(
        'performs the default add when none provided',
        windowSize,
        (WidgetTester tester) async {
          const valueToAdd = 'this is the value that will be added';
          final entryList = entries();
          final widget = EditableList(
            entries: entryList,
            textFieldLabel: label,
            gaRefreshSelection: '',
            gaScreen: '',
          );
          await tester.pumpWidget(
            wrapSimple(widget),
          );

          final actionBar = find.byType(EditableListActionBar);
          final textField = find.descendant(
            of: actionBar,
            matching: find.byType(TextField),
          );
          final addEntryButton = find.descendant(
            of: actionBar,
            matching: find.text('Add'),
          );
          await tester.enterText(textField, valueToAdd);
          await tester.tap(addEntryButton);
          await tester.pump();

          expect(entryList.value, contains(valueToAdd));
        },
      );

      testWidgetsWithWindowSize(
        'performs the default remove when no remove callback provided',
        windowSize,
        (WidgetTester tester) async {
          const valueToRemove = 'this is the value that will be removed';
          final entryList = entries([valueToRemove]);
          final widget = EditableList(
            entries: entryList,
            textFieldLabel: label,
            gaRefreshSelection: '',
            gaScreen: '',
          );
          await tester.pumpWidget(
            wrapSimple(widget),
          );
          final removeButton = find.byType(EditableListRemoveDirectoryButton);

          await tester.tap(removeButton);
          await tester.pump();

          expect(entryList.value, isNot(contains(valueToRemove)));
        },
      );
    });
  });
}
