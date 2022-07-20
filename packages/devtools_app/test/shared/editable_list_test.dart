import 'dart:ui';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/editable_list.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/test_utils.dart';

void main() {
  const windowSize = Size(1000.0, 1000.0);
  const label = 'This is the EditableList label';
  ValueListenable<List<String>> entries([
    List<String> values = const <String>[],
  ]) {
    return ListValueNotifier<String>(values);
  }

  setGlobal(IdeTheme, getIdeTheme());

  group('EditableList', () {
    testWidgetsWithWindowSize('shows the label', windowSize,
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          EditableList(entries: entries([]), textFieldLabel: label),
        ),
      );
      expect(find.text(label), findsOneWidget);
    });

    testWidgetsWithWindowSize('triggers add', windowSize,
        (WidgetTester tester) async {
      const valueToAdd = 'this is the value that will be added';
      String? entryThatWasRequestedForAdd;
      final widget = EditableList(
        entries: entries(),
        textFieldLabel: label,
        onEntryAdded: (e) {
          entryThatWasRequestedForAdd = e;
        },
      );
      await tester.pumpWidget(
        wrap(widget),
      );

      final textField = find.byKey(widget.textFieldKey);
      final addEntryButton = find.byKey(widget.addEntryButtonKey);
      await tester.enterText(textField, valueToAdd);
      await tester.tap(addEntryButton);
      await tester.pump();

      expect(entryThatWasRequestedForAdd, equals(valueToAdd));
    });

    testWidgetsWithWindowSize('triggers refresh', windowSize,
        (WidgetTester tester) async {
      var refreshWasCalled = false;
      final widget = EditableList(
        entries: entries(),
        textFieldLabel: label,
        onRefresh: () {
          refreshWasCalled = true;
        },
      );
      await tester.pumpWidget(
        wrap(widget),
      );
      final refreshButton = find.byKey(widget.refreshButtonKey);

      await tester.tap(refreshButton);
      await tester.pump();

      expect(refreshWasCalled, isTrue);
    });

    testWidgetsWithWindowSize('triggers remove', windowSize,
        (WidgetTester tester) async {
      const valueToRemove = 'this is the value that will be removed';
      String? entryThatWasRemoved;
      final widget = EditableList(
        entries: entries([valueToRemove]),
        textFieldLabel: label,
        onEntryRemoved: (e) {
          entryThatWasRemoved = e;
        },
      );
      await tester.pumpWidget(
        wrap(widget),
      );
      final row = find.byType(EditableListRow);
      final rowWidget = tester.firstWidget(row) as EditableListRow;
      final removeButton = find.descendant(
        of: row,
        matching: find.byKey(rowWidget.removeButtonKey),
      );

      await tester.tap(removeButton);
      await tester.pump();

      expect(entryThatWasRemoved, equals(valueToRemove));
    });

    testWidgetsWithWindowSize('copies an entry', windowSize,
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
      );
      await tester.pumpWidget(
        wrap(widget),
      );
      final row = find.byType(EditableListRow);
      final rowWidget = tester.firstWidget(row) as EditableListRow;
      final copyButton = find.descendant(
        of: row,
        matching: find.byKey(rowWidget.copyButtonKey),
      );

      await tester.tap(copyButton);
      await tester.pump();

      expect(clipboardContents, equals(valueToCopy));
    });
  });
}
