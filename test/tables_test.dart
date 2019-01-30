// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')
import 'dart:html';

import 'package:devtools/src/tables.dart';
import 'package:test/test.dart';

void main() {
  final List<TestData> oneThousandRows =
      List<TestData>.generate(1000, (int i) => TestData('Test Data $i'));

  group('static tables', () {
    Table<TestData> table;
    setUp(() async {
      table = Table<TestData>();
      // About 10 rows of data visible.
      table.element.element.style
        ..height = '300px'
        ..overflow = 'scroll';
      document.body.append(table.element.element);

      table.addColumn(TestColumn('Col One'));
      table.addColumn(TestColumn('Col Two'));
      table.setRows(oneThousandRows);

      await window.animationFrame;
    });
    tearDown(() => table?.element?.element?.remove());

    test('render all rows even when only a subset is visible', () async {
      // Expect 1001 due to spacer row.
      expect(table.element.element.querySelectorAll('tr').length, equals(1001));
    });
  });

  group('virtual tables', () {
    Table<TestData> table;
    setUp(() async {
      table = Table<TestData>.virtual();
      // About 10 rows of data visible.
      table.element.element.style
        ..height = '300px'
        ..overflow = 'scroll';
      document.body.append(table.element.element);

      table.addColumn(TestColumn('Col One'));
      table.addColumn(TestColumn('Col Two'));
      table.setRows(oneThousandRows);

      await window.animationFrame;
    });
    tearDown(() => table?.element?.element?.remove());

    test('render only a small number of rows', () async {
      expect(
          table.element.element.querySelectorAll('tr').length, lessThan(1100));
    });

    test('render rows starting around 0 when not scrolled', () async {
      final int rowNumber = getApproximatelyFirstRenderedDataIndex(table);
      expect(rowNumber, lessThan(5));
    });

    test('can selected by index', () async {
      final Element tbody = table.element.element.querySelector('tbody');

      table.selectByIndex(0);
      // Ensure a single visible row is marked as selected.
      expect(tbody.querySelectorAll('tr.selected'), hasLength(1));
    });

    test('can select an offscreen row then scroll it into view', () async {
      final Element tbody = table.element.element.querySelector('tbody');

      // Select a row that will be offscreen.
      table.selectByIndex(500, keepVisible: false);
      // Ensure there are no selected rows.
      expect(tbody.querySelectorAll('tr.selected'), isEmpty);

      // Scroll to approx row 500.
      table.element.scrollTop = 29 * 500;

      // Wait for two frames, to ensure that the onScroll fired and then we
      // definitely rebuilt the table.
      await window.animationFrame;
      await window.animationFrame;

      // Ensure there is now a single visible row marked as selected.
      expect(tbody.querySelectorAll('tr.selected'), hasLength(1));
    });

    test('scrolls to the selection automatically', () async {
      final Element tbody = table.element.element.querySelector('tbody');

      // Select a row that is offscreen.
      table.selectByIndex(500, scrollBehavior: 'instant');

      // Wait for two frames, to ensure that the onScroll fired and then we
      // definitely rebuilt the table.
      await window.animationFrame;
      await window.animationFrame;

      // Ensure there is now a single visible row marked as selected.
      expect(tbody.querySelectorAll('tr.selected'), hasLength(1));
      final int rowNumber = getApproximatelyFirstRenderedDataIndex(table);
      expect(rowNumber, greaterThan(450));
      expect(rowNumber, lessThan(550));
    });

    test('render rows starting around 500 when scrolled down the page',
        () async {
      // Scroll to approx row 500.
      table.element.scrollTop = 29 * 500;

      // Wait for two frames, to ensure that the onScroll fired and then we
      // definitely rebuilt the table.
      await window.animationFrame;
      await window.animationFrame;

      final int rowNumber = getApproximatelyFirstRenderedDataIndex(table);
      expect(rowNumber, greaterThan(450));
      expect(rowNumber, lessThan(550));
    });
  });
}

int getApproximatelyFirstRenderedDataIndex(Table<TestData> table) {
  // It's possible we have a spacer row and a dummy row to force the alternating
  // colour to line up, so look at the third row (index: 2) to ensure it's
  // approximately what we'd expect.
  final Element dataRow =
      table.element.element.querySelector('tbody').children[2];
  final Element cell = dataRow.querySelector('td');
  expect(cell.text, contains('Test Data '));
  final int rowNumber = int.tryParse(cell.text.replaceAll('Test Data ', ''));
  return rowNumber;
}

class TestData {
  TestData(this.message);

  final String message;
}

class TestColumn extends Column<TestData> {
  TestColumn(String name) : super(name);

  @override
  dynamic getValue(TestData item) => item.message;

  @override
  String render(dynamic value) {
    return value;
  }
}
