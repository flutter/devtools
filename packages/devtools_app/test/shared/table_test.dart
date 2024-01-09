// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/table/column_widths.dart';
import 'package:devtools_app/src/shared/table/table.dart';
import 'package:devtools_app/src/shared/table/table_controller.dart';
import 'package:devtools_app/src/shared/table/table_data.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _NonSortableFlatNameColumn extends ColumnData<TestData> {
  _NonSortableFlatNameColumn.wide(super.title) : super.wide();

  @override
  String getValue(TestData dataObject) {
    return dataObject.name;
  }

  @override
  bool get supportsSorting => false;
}

class _NonSortableFlatNumColumn extends ColumnData<TestData> {
  _NonSortableFlatNumColumn.wide(super.title) : super.wide();

  @override
  int getValue(TestData dataObject) {
    return dataObject.number;
  }

  @override
  bool get supportsSorting => false;

  @override
  bool get numeric => true;
}

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(IdeTheme, IdeTheme());
    TableUiStateStore.clear();
  });

  group('FlatTable view', () {
    late List<TestData> flatData;
    late ColumnData<TestData> flatNameColumn;

    setUp(() {
      flatNameColumn = _FlatNameColumn();
      flatData = [
        TestData('Foo', 0),
        TestData('Bar', 1),
        TestData('Baz', 2),
        TestData('Qux', 3),
        TestData('Snap', 4),
        TestData('Crackle', 5),
        TestData('Pop', 5),
        TestData('Baz', 6),
        TestData('Qux', 7),
      ];
    });

    testWidgets('displays with simple content', (WidgetTester tester) async {
      final table = FlatTable<TestData>(
        columns: [flatNameColumn],
        data: [TestData('empty', 0)],
        dataKey: 'test-data',
        keyFactory: (d) => Key(d.name),
        defaultSortColumn: flatNameColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      expect(find.byWidget(table), findsOneWidget);
      expect(find.text('FlatName'), findsOneWidget);

      final FlatTableState state = tester.state(find.byWidget(table));
      final columnWidths =
          state.tableController.computeColumnWidthsSizeToFit(1000);
      expect(columnWidths.length, 1);
      expect(columnWidths.first, 300);
      expect(find.byKey(const Key('empty')), findsOneWidget);
    });

    testWidgets(
      'displays with simple content size to content',
      (WidgetTester tester) async {
        final table = FlatTable<TestData>(
          columns: [flatNameColumn],
          data: [TestData('empty', 0)],
          dataKey: 'test-data',
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: flatNameColumn,
          defaultSortDirection: SortDirection.ascending,
          sizeColumnsToFit: false,
        );
        await tester.pumpWidget(wrap(table));
        expect(find.byWidget(table), findsOneWidget);
        expect(find.text('FlatName'), findsOneWidget);

        final FlatTableState state = tester.state(find.byWidget(table));
        expect(state.tableController.columnWidths, isNotNull);
        final columnWidths = state.tableController.columnWidths!;
        expect(columnWidths.length, 1);
        expect(columnWidths.first, 300);
        expect(find.byKey(const Key('empty')), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'displays with full content',
      const Size(800.0, 1200.0),
      (WidgetTester tester) async {
        final table = FlatTable<TestData>(
          columns: [
            flatNameColumn,
            _NumberColumn(),
          ],
          data: flatData,
          dataKey: 'test-data',
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: flatNameColumn,
          defaultSortDirection: SortDirection.ascending,
        );
        await tester.pumpWidget(wrap(table));
        expect(find.byWidget(table), findsOneWidget);

        // Column headers.
        expect(find.text('FlatName'), findsOneWidget);
        expect(find.text('Number'), findsOneWidget);

        // Table data.
        expect(find.byKey(const Key('Foo')), findsOneWidget);
        expect(find.byKey(const Key('Bar')), findsOneWidget);
        // Note that two keys with the same name are allowed but not necessarily a
        // good idea. We should be using unique identifiers for keys.
        expect(find.byKey(const Key('Baz')), findsNWidgets(2));
        expect(find.byKey(const Key('Qux')), findsNWidgets(2));
        expect(find.byKey(const Key('Snap')), findsOneWidget);
        expect(find.byKey(const Key('Crackle')), findsOneWidget);
        expect(find.byKey(const Key('Pop')), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'displays with column groups',
      const Size(800.0, 1200.0),
      (WidgetTester tester) async {
        final table = FlatTable<TestData>(
          columns: [
            flatNameColumn,
            _NumberColumn(),
          ],
          columnGroups: [
            ColumnGroup.fromText(
              title: 'Group 1',
              range: const Range(0, 1),
            ),
            ColumnGroup.fromText(
              title: 'Group 2',
              range: const Range(1, 2),
            ),
          ],
          data: flatData,
          dataKey: 'test-data',
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: flatNameColumn,
          defaultSortDirection: SortDirection.ascending,
        );
        await tester.pumpWidget(wrap(table));
        expect(find.byWidget(table), findsOneWidget);
        // Column group headers.
        expect(find.text('Group 1'), findsOneWidget);
        expect(find.text('Group 2'), findsOneWidget);

        // Column headers.
        expect(find.text('FlatName'), findsOneWidget);
        expect(find.text('Number'), findsOneWidget);

        // Table data.
        expect(find.byKey(const Key('Foo')), findsOneWidget);
        expect(find.byKey(const Key('Bar')), findsOneWidget);
        // Note that two keys with the same name are allowed but not necessarily a
        // good idea. We should be using unique identifiers for keys.
        expect(find.byKey(const Key('Baz')), findsNWidgets(2));
        expect(find.byKey(const Key('Qux')), findsNWidgets(2));
        expect(find.byKey(const Key('Snap')), findsOneWidget);
        expect(find.byKey(const Key('Crackle')), findsOneWidget);
        expect(find.byKey(const Key('Pop')), findsOneWidget);
      },
    );

    testWidgets('starts with sorted data', (WidgetTester tester) async {
      expect(flatData[0].name, equals('Foo'));
      expect(flatData[1].name, equals('Bar'));
      expect(flatData[2].name, equals('Baz'));
      expect(flatData[3].name, equals('Qux'));
      expect(flatData[4].name, equals('Snap'));
      expect(flatData[5].name, equals('Crackle'));
      expect(flatData[6].name, equals('Pop'));
      expect(flatData[7].name, equals('Baz'));
      expect(flatData[8].name, equals('Qux'));
      final table = FlatTable<TestData>(
        columns: [
          flatNameColumn,
          _NumberColumn(),
        ],
        data: flatData,
        dataKey: 'test-data',
        keyFactory: (d) => Key(d.name),
        defaultSortColumn: flatNameColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      final FlatTableState<TestData> state = tester.state(find.byWidget(table));
      final data = state.tableController.tableData.value.data;
      expect(data[0].name, equals('Bar'));
      expect(data[1].name, equals('Baz'));
      expect(data[2].name, equals('Baz'));
      expect(data[3].name, equals('Crackle'));
      expect(data[4].name, equals('Foo'));
      expect(data[5].name, equals('Pop'));
      expect(data[6].name, equals('Qux'));
      expect(data[7].name, equals('Qux'));
      expect(data[8].name, equals('Snap'));
    });

    testWidgets('sorts data by column', (WidgetTester tester) async {
      final table = FlatTable<TestData>(
        columns: [
          flatNameColumn,
          _NumberColumn(),
        ],
        data: flatData,
        dataKey: 'test-data',
        keyFactory: (d) => Key(d.name),
        defaultSortColumn: flatNameColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      final FlatTableState<TestData> state = tester.state(find.byWidget(table));
      {
        final data = state.tableController.tableData.value.data;
        expect(data[0].name, equals('Bar'));
        expect(data[1].name, equals('Baz'));
        expect(data[2].name, equals('Baz'));
        expect(data[3].name, equals('Crackle'));
        expect(data[4].name, equals('Foo'));
        expect(data[5].name, equals('Pop'));
        expect(data[6].name, equals('Qux'));
        expect(data[7].name, equals('Qux'));
        expect(data[8].name, equals('Snap'));
      }
      // Reverse the sort direction.
      await tester.tap(find.text('FlatName'));
      await tester.pumpAndSettle();

      {
        final data = state.tableController.tableData.value.data;
        expect(data[8].name, equals('Bar'));
        expect(data[7].name, equals('Baz'));
        expect(data[6].name, equals('Baz'));
        expect(data[5].name, equals('Crackle'));
        expect(data[4].name, equals('Foo'));
        expect(data[3].name, equals('Pop'));
        expect(data[2].name, equals('Qux'));
        expect(data[1].name, equals('Qux'));
        expect(data[0].name, equals('Snap'));
      }

      // Change the sort column.
      await tester.tap(find.text('Number'));
      await tester.pumpAndSettle();

      {
        final data = state.tableController.tableData.value.data;
        expect(data[0].name, equals('Foo'));
        expect(data[1].name, equals('Bar'));
        expect(data[2].name, equals('Baz'));
        expect(data[3].name, equals('Qux'));
        expect(data[4].name, equals('Snap'));
        expect(data[5].name, equals('Crackle'));
        expect(data[6].name, equals('Pop'));
        expect(data[7].name, equals('Baz'));
        expect(data[8].name, equals('Qux'));
      }
    });

    testWidgets(
      'does not sort with supportsSorting == false',
      (WidgetTester tester) async {
        final nonSortableFlatNameColumn =
            _NonSortableFlatNameColumn.wide('FlatName');
        final nonSortableFlatNumColumn =
            _NonSortableFlatNumColumn.wide('Number');
        final table = FlatTable<TestData>(
          columns: [
            nonSortableFlatNameColumn,
            nonSortableFlatNumColumn,
          ],
          data: flatData,
          dataKey: 'test-data',
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: nonSortableFlatNameColumn,
          defaultSortDirection: SortDirection.ascending,
        );
        await tester.pumpWidget(wrap(table));
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        {
          final data = state.tableController.tableData.value.data;
          expect(data[0].name, equals('Bar'));
          expect(data[1].name, equals('Baz'));
          expect(data[2].name, equals('Baz'));
          expect(data[3].name, equals('Crackle'));
          expect(data[4].name, equals('Foo'));
          expect(data[5].name, equals('Pop'));
          expect(data[6].name, equals('Qux'));
          expect(data[7].name, equals('Qux'));
          expect(data[8].name, equals('Snap'));
        }

        // Attempt to reverse the sort direction.
        await tester.tap(find.text('FlatName'));
        await tester.pumpAndSettle();

        {
          final data = state.tableController.tableData.value.data;
          expect(data[0].name, equals('Bar'));
          expect(data[1].name, equals('Baz'));
          expect(data[2].name, equals('Baz'));
          expect(data[3].name, equals('Crackle'));
          expect(data[4].name, equals('Foo'));
          expect(data[5].name, equals('Pop'));
          expect(data[6].name, equals('Qux'));
          expect(data[7].name, equals('Qux'));
          expect(data[8].name, equals('Snap'));
        }

        // Attempt to change the sort column.
        await tester.tap(find.text('Number'));
        await tester.pumpAndSettle();
        {
          final data = state.tableController.tableData.value.data;
          expect(data[0].name, equals('Bar'));
          expect(data[1].name, equals('Baz'));
          expect(data[2].name, equals('Baz'));
          expect(data[3].name, equals('Crackle'));
          expect(data[4].name, equals('Foo'));
          expect(data[5].name, equals('Pop'));
          expect(data[6].name, equals('Qux'));
          expect(data[7].name, equals('Qux'));
          expect(data[8].name, equals('Snap'));
        }
      },
    );

    testWidgets(
      'sorts data by column and secondary column',
      (WidgetTester tester) async {
        final numberColumn = _NumberColumn();
        final table = FlatTable<TestData>(
          columns: [
            flatNameColumn,
            numberColumn,
          ],
          data: [
            TestData('Foo', 0),
            TestData('1 Bar', 1),
            TestData('# Baz', 2),
            TestData('Qux', 3),
            TestData('Snap', 4),
            TestData('Crackle', 4),
            TestData('Pop', 4),
            TestData('Bang', 4),
            TestData('Qux', 5),
          ],
          dataKey: 'test-data',
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: numberColumn,
          defaultSortDirection: SortDirection.ascending,
          secondarySortColumn: flatNameColumn,
        );
        await tester.pumpWidget(wrap(table));
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        {
          final data = state.tableController.tableData.value.data;
          expect(data[0].name, equals('Foo'));
          expect(data[1].name, equals('1 Bar'));
          expect(data[2].name, equals('# Baz'));
          expect(data[3].name, equals('Qux'));
          expect(data[4].name, equals('Bang'));
          expect(data[5].name, equals('Crackle'));
          expect(data[6].name, equals('Pop'));
          expect(data[7].name, equals('Snap'));
          expect(data[8].name, equals('Qux'));
        }

        // Reverse the sort direction.
        await tester.tap(find.text('Number'));
        await tester.pumpAndSettle();

        {
          final data = state.tableController.tableData.value.data;
          expect(data[8].name, equals('Foo'));
          expect(data[7].name, equals('1 Bar'));
          expect(data[6].name, equals('# Baz'));
          expect(data[5].name, equals('Qux'));
          expect(data[4].name, equals('Bang'));
          expect(data[3].name, equals('Crackle'));
          expect(data[2].name, equals('Pop'));
          expect(data[1].name, equals('Snap'));
          expect(data[0].name, equals('Qux'));
        }
        // Change the sort column.
        await tester.tap(find.text('FlatName'));
        await tester.pumpAndSettle();

        {
          final data = state.tableController.tableData.value.data;
          expect(data[0].name, equals('# Baz'));
          expect(data[1].name, equals('1 Bar'));
          expect(data[2].name, equals('Bang'));
          expect(data[3].name, equals('Crackle'));
          expect(data[4].name, equals('Foo'));
          expect(data[5].name, equals('Pop'));
          expect(data[6].name, equals('Qux'));
          expect(data[7].name, equals('Qux'));
          expect(data[8].name, equals('Snap'));
        }
      },
    );

    testWidgets('displays with many columns', (WidgetTester tester) async {
      final table = FlatTable<TestData>(
        columns: [
          _NumberColumn(),
          _CombinedColumn(),
          flatNameColumn,
          _CombinedColumn(),
        ],
        data: flatData,
        dataKey: 'test-data',
        keyFactory: (data) => Key(data.name),
        defaultSortColumn: flatNameColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 200.0,
            height: 200.0,
            child: table,
          ),
        ),
      );
      expect(find.byWidget(table), findsOneWidget);
      // TODO(jacobr): add a golden image test.
    });

    testWidgets('displays with wide column', (WidgetTester tester) async {
      final table = FlatTable<TestData>(
        columns: [
          flatNameColumn,
          _NumberColumn(),
          _WideColumn(),
        ],
        data: flatData,
        dataKey: 'test-data',
        keyFactory: (data) => Key(data.name),
        defaultSortColumn: flatNameColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 800.0,
            height: 200.0,
            child: table,
          ),
        ),
      );
      expect(find.byWidget(table), findsOneWidget);
      {
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        final columnWidths =
            state.tableController.computeColumnWidthsSizeToFit(800.0);
        expect(columnWidths.length, equals(3));
        expect(columnWidths[0], equals(300.0));
        expect(columnWidths[1], equals(400.0));
        expect(columnWidths[2], equals(52.0));
      }

      // TODO(jacobr): add a golden image test.

      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 200.0,
            height: 200.0,
            child: table,
          ),
        ),
      );

      {
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        final columnWidths =
            state.tableController.computeColumnWidthsSizeToFit(200.0);
        expect(columnWidths.length, equals(3));
        expect(columnWidths[0], equals(300.0)); // Fixed width column.
        expect(columnWidths[1], equals(400.0)); // Fixed width column.
        expect(columnWidths[2], equals(0.0)); // Variable width column.
      }

      // TODO(jacobr): add a golden image test.
    });

    testWidgets(
      'displays with wide column size to content',
      (WidgetTester tester) async {
        final table = FlatTable<TestData>(
          columns: [
            flatNameColumn,
            _NumberColumn(),
            _WideColumn(),
          ],
          data: flatData,
          dataKey: 'test-data',
          keyFactory: (data) => Key(data.name),
          defaultSortColumn: flatNameColumn,
          defaultSortDirection: SortDirection.ascending,
          sizeColumnsToFit: false,
        );
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 800.0,
              height: 200.0,
              child: table,
            ),
          ),
        );
        expect(find.byWidget(table), findsOneWidget);
        {
          final FlatTableState<TestData> state =
              tester.state(find.byWidget(table));
          expect(state.tableController.columnWidths, isNotNull);
          final columnWidths = state.tableController.columnWidths!;
          expect(columnWidths.length, equals(3));
          expect(columnWidths[0], equals(300.0));
          expect(columnWidths[1], equals(400.0));
          expect(columnWidths[2], equals(369.0));
        }

        // TODO(jacobr): add a golden image test.

        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 200.0,
              height: 200.0,
              child: table,
            ),
          ),
        );

        {
          final FlatTableState<TestData> state =
              tester.state(find.byWidget(table));
          expect(state.tableController.columnWidths, isNotNull);
          final columnWidths = state.tableController.columnWidths!;
          expect(columnWidths.length, equals(3));
          expect(columnWidths[0], equals(300.0)); // Fixed width column.
          expect(columnWidths[1], equals(400.0)); // Fixed width column.
          expect(columnWidths[2], equals(369.0)); // Variable width column.
        }

        // TODO(jacobr): add a golden image test.
      },
    );

    testWidgets(
      'displays with multiple wide columns',
      (WidgetTester tester) async {
        final table = FlatTable<TestData>(
          columns: [
            flatNameColumn,
            _WideMinWidthColumn(),
            _NumberColumn(),
            _WideColumn(),
          ],
          data: flatData,
          dataKey: 'test-data',
          keyFactory: (data) => Key(data.name),
          defaultSortColumn: flatNameColumn,
          defaultSortDirection: SortDirection.ascending,
        );
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 1000.0,
              height: 200.0,
              child: table,
            ),
          ),
        );
        expect(find.byWidget(table), findsOneWidget);
        {
          final FlatTableState<TestData> state =
              tester.state(find.byWidget(table));
          final columnWidths =
              state.tableController.computeColumnWidthsSizeToFit(1000.0);
          expect(columnWidths.length, equals(4));
          expect(columnWidths[0], equals(300.0)); // Fixed width column.
          expect(columnWidths[1], equals(120.0)); // Min width wide column
          expect(columnWidths[2], equals(400.0)); // Fixed width column.
          expect(columnWidths[3], equals(120.0)); // Variable width wide column.
        }

        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 200.0,
              height: 200.0,
              child: table,
            ),
          ),
        );
        {
          final FlatTableState<TestData> state =
              tester.state(find.byWidget(table));
          final columnWidths =
              state.tableController.computeColumnWidthsSizeToFit(200.0);
          expect(columnWidths.length, equals(4));
          expect(columnWidths[0], equals(300.0)); // Fixed width column.
          expect(columnWidths[1], equals(100.0)); // Min width wide column
          expect(columnWidths[2], equals(400.0)); // Fixed width column.
          expect(columnWidths[3], equals(0.0)); // Variable width wide column.
        }
      },
    );

    testWidgets(
      'displays with multiple min width wide columns',
      (WidgetTester tester) async {
        final table = FlatTable<TestData>(
          columns: [
            flatNameColumn,
            _WideMinWidthColumn(),
            _VeryWideMinWidthColumn(),
            _NumberColumn(),
            _WideColumn(),
          ],
          data: flatData,
          dataKey: 'test-data',
          keyFactory: (data) => Key(data.name),
          defaultSortColumn: flatNameColumn,
          defaultSortDirection: SortDirection.ascending,
        );
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 1501.0,
              height: 200.0,
              child: table,
            ),
          ),
        );
        expect(find.byWidget(table), findsOneWidget);
        {
          final FlatTableState<TestData> state =
              tester.state(find.byWidget(table));
          final columnWidths =
              state.tableController.computeColumnWidthsSizeToFit(1501.0);
          expect(columnWidths.length, equals(5));
          expect(columnWidths[0], equals(300.0)); // Fixed width column.
          expect(columnWidths[1], equals(243.0)); // Min width wide column
          expect(
            columnWidths[2],
            equals(243.0),
          ); // Very wide min width wide column
          expect(columnWidths[3], equals(400.0)); // Fixed width column.
          expect(columnWidths[4], equals(243.0)); // Variable width wide column.
        }

        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 1200.0,
              height: 200.0,
              child: table,
            ),
          ),
        );
        expect(find.byWidget(table), findsOneWidget);
        {
          final FlatTableState<TestData> state =
              tester.state(find.byWidget(table));
          final columnWidths =
              state.tableController.computeColumnWidthsSizeToFit(1200.0);
          expect(columnWidths.length, equals(5));
          expect(columnWidths[0], equals(300.0)); // Fixed width column.
          expect(columnWidths[1], equals(134.0)); // Min width wide column
          expect(
            columnWidths[2],
            equals(160.0),
          ); // Very wide min width wide column
          expect(columnWidths[3], equals(400.0)); // Fixed width column.
          expect(columnWidths[4], equals(134.0)); // Variable width wide column.
        }

        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 1000.0,
              height: 200.0,
              child: table,
            ),
          ),
        );
        expect(find.byWidget(table), findsOneWidget);
        {
          final FlatTableState<TestData> state =
              tester.state(find.byWidget(table));
          final columnWidths =
              state.tableController.computeColumnWidthsSizeToFit(1000.0);
          expect(columnWidths.length, equals(5));
          expect(columnWidths[0], equals(300.0)); // Fixed width column.
          expect(columnWidths[1], equals(100.0)); // Min width wide column
          expect(
            columnWidths[2],
            equals(160.0),
          ); // Very wide min width wide column
          expect(columnWidths[3], equals(400.0)); // Fixed width column.
          expect(columnWidths[4], equals(0.0)); // Variable width wide column.
        }
      },
    );

    testWidgets('can select an item', (WidgetTester tester) async {
      TestData? selected;
      final testData = TestData('empty', 0);
      const key = Key('empty');
      final table = FlatTable<TestData>(
        columns: [flatNameColumn],
        data: [testData],
        dataKey: 'test-data',
        keyFactory: (d) => Key(d.name),
        onItemSelected: (item) => selected = item,
        defaultSortColumn: flatNameColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      expect(find.byWidget(table), findsOneWidget);
      expect(find.byKey(key), findsOneWidget);
      expect(selected, isNull);
      await tester.tap(find.byKey(key));
      expect(selected, testData);
    });

    testWidgets('can pin items (original)', (WidgetTester tester) async {
      final column = _PinnableFlatNameColumn();
      final testData = [
        for (int i = 0; i < 10; ++i)
          PinnableTestData(name: i.toString(), enabled: i % 2 == 0),
      ];

      final table = FlatTable<PinnableTestData>(
        columns: [column],
        data: testData,
        dataKey: 'test-data',
        keyFactory: (d) => Key(d.name),
        defaultSortColumn: column,
        defaultSortDirection: SortDirection.ascending,
        pinBehavior: FlatTablePinBehavior.pinOriginalToTop,
      );
      await tester.pumpWidget(wrap(table));

      expect(find.byWidget(table), findsOneWidget);

      final FlatTableState<PinnableTestData> state = tester.state(
        find.byWidget(table),
      );

      var pinnedData = state.tableController.pinnedData;
      expect(pinnedData.length, testData.length / 2);
      for (int i = 0; i < pinnedData.length; ++i) {
        expect(pinnedData[i].name, (i * 2).toString());
        expect(pinnedData[i].enabled, true);
      }

      var data = state.tableController.tableData.value.data;
      expect(data.length, testData.length / 2);
      for (int i = 0; i < data.length; ++i) {
        expect(data[i].name, ((i * 2) + 1).toString());
        expect(data[i].enabled, false);
      }

      // Sorting should apply to both pinned and unpinned items.
      await tester.tap(find.text(column.title));
      await tester.pumpAndSettle();

      data = state.tableController.tableData.value.data;
      pinnedData = state.tableController.pinnedData;
      expect(pinnedData.length, testData.length / 2);
      for (int i = 0; i < pinnedData.length; ++i) {
        final index = data.length - i - 1;
        expect(pinnedData[i].name, (index * 2).toString());
        expect(pinnedData[i].enabled, true);
      }
      expect(data.length, testData.length / 2);
      for (int i = 0; i < data.length; ++i) {
        final index = data.length - i - 1;
        expect(
          data[i].name,
          ((index * 2) + 1).toString(),
        );
        expect(data[i].enabled, false);
      }
    });

    testWidgets('can pin items (copy)', (WidgetTester tester) async {
      final column = _PinnableFlatNameColumn();
      final testData = [
        for (int i = 0; i < 10; ++i)
          PinnableTestData(name: i.toString(), enabled: i % 2 == 0),
      ];

      final table = FlatTable<PinnableTestData>(
        columns: [column],
        data: testData,
        dataKey: 'test-data',
        keyFactory: (d) => Key(d.name),
        defaultSortColumn: column,
        defaultSortDirection: SortDirection.ascending,
        pinBehavior: FlatTablePinBehavior.pinCopyToTop,
      );
      await tester.pumpWidget(wrap(table));

      expect(find.byWidget(table), findsOneWidget);

      final FlatTableState<PinnableTestData> state = tester.state(
        find.byWidget(table),
      );

      var data = state.tableController.tableData.value.data;
      var pinnedData = state.tableController.pinnedData;
      expect(pinnedData.length, testData.length / 2);
      for (int i = 0; i < pinnedData.length; ++i) {
        expect(pinnedData[i].name, (i * 2).toString());
        expect(pinnedData[i].enabled, true);
      }
      expect(data.length, testData.length);
      for (int i = 0; i < data.length; ++i) {
        expect(data[i].name, i.toString());
        expect(data[i].enabled, i % 2 == 0);
      }

      // Sorting should apply to both pinned and unpinned items.
      await tester.tap(find.text(column.title));
      await tester.pumpAndSettle();

      data = state.tableController.tableData.value.data;
      pinnedData = state.tableController.pinnedData;
      expect(pinnedData.length, testData.length / 2);
      for (int i = 0; i < pinnedData.length; ++i) {
        final index = pinnedData.length - i - 1;
        expect(pinnedData[i].name, (index * 2).toString());
        expect(pinnedData[i].enabled, true);
      }
      expect(data.length, testData.length);
      for (int i = 0; i < data.length; ++i) {
        final index = data.length - i - 1;
        expect(
          data[i].name,
          index.toString(),
        );
        expect(data[i].enabled, index % 2 == 0);
      }
    });
  });

  group('TreeTable view', () {
    late TestData tree1;
    late TestData tree2;
    late TreeColumnData<TestData> treeColumn;

    setUp(() {
      treeColumn = _NameColumn();
      _NumberColumn();
      tree1 = TestData('Foo', 0)
        ..children.addAll([
          TestData('Bar', 1)
            ..children.addAll([
              TestData('Baz', 2),
              TestData('Qux', 3),
              TestData('Snap', 4),
              TestData('Crackle', 5),
              TestData('Pop', 5),
            ]),
          TestData('Baz', 7),
          TestData('Qux', 6),
        ])
        ..expandCascading();
      tree2 = TestData('Foo_2', 0)
        ..children.add(
          TestData('Bar_2', 1)
            ..children.add(
              TestData('Snap_2', 2),
            ),
        )
        ..expandCascading();
    });

    testWidgets('displays with simple content', (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [treeColumn],
        dataRoots: [TestData('empty', 0)],
        dataKey: 'test-data',
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        defaultSortColumn: treeColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      expect(find.byWidget(table), findsOneWidget);
      expect(find.byKey(const Key('empty')), findsOneWidget);
    });

    testWidgets(
      'displays with multiple data roots',
      (WidgetTester tester) async {
        final table = TreeTable<TestData>(
          columns: [treeColumn],
          dataRoots: [tree1, tree2],
          dataKey: 'test-data',
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: treeColumn,
          defaultSortDirection: SortDirection.ascending,
        );
        await tester.pumpWidget(wrap(table));
        expect(find.byWidget(table), findsOneWidget);
        expect(find.byKey(const Key('Foo')), findsOneWidget);
        expect(find.byKey(const Key('Bar')), findsOneWidget);
        expect(find.byKey(const Key('Snap')), findsOneWidget);
        expect(find.byKey(const Key('Foo_2')), findsOneWidget);
        expect(find.byKey(const Key('Bar_2')), findsOneWidget);
        expect(find.byKey(const Key('Snap_2')), findsOneWidget);
        expect(tree1.isExpanded, isTrue);
        expect(tree2.isExpanded, isTrue);

        await tester.tap(find.byKey(const Key('Foo')));
        await tester.pumpAndSettle();
        expect(tree1.isExpanded, isFalse);
        expect(tree2.isExpanded, isTrue);

        await tester.tap(find.byKey(const Key('Foo_2')));
        expect(tree1.isExpanded, isFalse);
        expect(tree2.isExpanded, isFalse);

        await tester.tap(find.byKey(const Key('Foo')));
        expect(tree1.isExpanded, isTrue);
        expect(tree2.isExpanded, isFalse);
      },
    );

    testWidgets(
      'displays when widget changes dataRoots',
      (WidgetTester tester) async {
        final table = TreeTable<TestData>(
          columns: [treeColumn],
          dataRoots: [tree1, tree2],
          dataKey: 'test-data',
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: treeColumn,
          defaultSortDirection: SortDirection.ascending,
        );
        await tester.pumpWidget(wrap(table));
        expect(find.byWidget(table), findsOneWidget);
        expect(find.byKey(const Key('Foo')), findsOneWidget);
        expect(find.byKey(const Key('Bar')), findsOneWidget);
        expect(find.byKey(const Key('Snap')), findsOneWidget);
        expect(find.byKey(const Key('Foo_2')), findsOneWidget);
        expect(find.byKey(const Key('Bar_2')), findsOneWidget);
        expect(find.byKey(const Key('Snap_2')), findsOneWidget);
        expect(tree1.isExpanded, isTrue);
        expect(tree2.isExpanded, isTrue);

        final newTable = TreeTable<TestData>(
          columns: [treeColumn],
          dataRoots: [TestData('root1', 0), TestData('root2', 1)],
          dataKey: 'test-data',
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: treeColumn,
          defaultSortDirection: SortDirection.descending,
        );
        await tester.pumpWidget(wrap(newTable));
        expect(find.byKey(const Key('Foo')), findsNothing);
        expect(find.byKey(const Key('Bar')), findsNothing);
        expect(find.byKey(const Key('Snap')), findsNothing);
        expect(find.byKey(const Key('Foo_2')), findsNothing);
        expect(find.byKey(const Key('Bar_2')), findsNothing);
        expect(find.byKey(const Key('Snap_2')), findsNothing);
        expect(find.byKey(const Key('root1')), findsOneWidget);
        expect(find.byKey(const Key('root2')), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      'displays with tree column first',
      const Size(800.0, 1200.0),
      (WidgetTester tester) async {
        final table = TreeTable<TestData>(
          columns: [
            treeColumn,
            _NumberColumn(),
          ],
          dataRoots: [tree1],
          dataKey: 'test-data',
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: treeColumn,
          defaultSortDirection: SortDirection.descending,
        );
        await tester.pumpWidget(wrap(table));
        expect(find.byWidget(table), findsOneWidget);
        expect(find.byKey(const Key('Foo')), findsOneWidget);
        expect(find.byKey(const Key('Bar')), findsOneWidget);
        // Note that two keys with the same name are allowed but not necessarily a
        // good idea. We should be using unique identifiers for keys.
        expect(find.byKey(const Key('Baz')), findsNWidgets(2));
        expect(find.byKey(const Key('Qux')), findsNWidgets(2));
        expect(find.byKey(const Key('Snap')), findsOneWidget);
        expect(find.byKey(const Key('Crackle')), findsOneWidget);
        expect(find.byKey(const Key('Pop')), findsOneWidget);
      },
    );

    testWidgets('displays with many columns', (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [
          _NumberColumn(),
          _CombinedColumn(),
          treeColumn,
          _CombinedColumn(),
        ],
        dataRoots: [tree1],
        dataKey: 'test-data',
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        defaultSortColumn: treeColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 200.0,
            height: 200.0,
            child: table,
          ),
        ),
      );
      expect(find.byWidget(table), findsOneWidget);
    });

    testWidgets(
      'displays wide data with many columns',
      (WidgetTester tester) async {
        const strings = <String>[
          'All work',
          'and no play',
          'makes Ben',
          'a dull boy',
          // String is maybe a little easier to read this way.
          // ignore: no_adjacent_strings_in_list
          'The quick brown fox jumps over the lazy dog, although the fox '
              "can't jump very high and the dog is very, very small, so it really"
              " isn't much of an achievement on the fox's part, so I'm not sure why "
              "we're even talking about it.",
        ];
        final root = TestData('Root', 0);
        var current = root;
        for (int i = 0; i < 1000; ++i) {
          final next = TestData(strings[i % strings.length], i);
          current.addChild(next);
          current = next;
        }
        root.expandCascading();
        final table = TreeTable<TestData>(
          columns: [
            _NumberColumn(),
            _CombinedColumn(),
            treeColumn,
            _CombinedColumn(),
          ],
          dataRoots: [root],
          dataKey: 'test-data',
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: treeColumn,
          defaultSortDirection: SortDirection.ascending,
        );
        await tester.pumpWidget(
          wrap(
            SizedBox(
              width: 200.0,
              height: 200.0,
              child: table,
            ),
          ),
        );

        expect(find.byWidget(table), findsOneWidget);
        // Regression test for https://github.com/flutter/devtools/issues/4786
        expect(
          find.text(
            '\u2026', // Unicode '...'
            findRichText: true,
            skipOffstage: false,
          ),
          findsNothing,
        );
        expect(
          find.text(
            'Root',
            findRichText: true,
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        for (final str in strings) {
          expect(
            find.text(
              str,
              findRichText: true,
              skipOffstage: false,
            ),
            findsWidgets,
          );
        }
      },
    );

    testWidgets(
      'properly collapses and expands the tree',
      (WidgetTester tester) async {
        final table = TreeTable<TestData>(
          columns: [
            _NumberColumn(),
            treeColumn,
          ],
          dataRoots: [tree1],
          dataKey: 'test-data',
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: treeColumn,
          defaultSortDirection: SortDirection.ascending,
        );
        await tester.pumpWidget(wrap(table));
        await tester.pumpAndSettle();

        expect(tree1.isExpanded, true);
        await tester.tap(find.byKey(const Key('Foo')));
        await tester.pumpAndSettle();
        expect(tree1.isExpanded, false);
        await tester.tap(find.byKey(const Key('Foo')));
        await tester.pumpAndSettle();
        expect(tree1.isExpanded, true);
        await tester.tap(find.byKey(const Key('Bar')));
        await tester.pumpAndSettle();
        expect(tree1.children[0].isExpanded, false);
      },
    );

    testWidgets('starts with sorted data', (WidgetTester tester) async {
      expect(tree1.children[0].name, equals('Bar'));
      expect(tree1.children[0].children[0].name, equals('Baz'));
      expect(tree1.children[0].children[1].name, equals('Qux'));
      expect(tree1.children[0].children[2].name, equals('Snap'));
      expect(tree1.children[0].children[3].name, equals('Crackle'));
      expect(tree1.children[0].children[4].name, equals('Pop'));
      expect(tree1.children[1].name, equals('Baz'));
      expect(tree1.children[2].name, equals('Qux'));
      final table = TreeTable<TestData>(
        columns: [
          _NumberColumn(),
          treeColumn,
        ],
        dataRoots: [tree1],
        dataKey: 'test-data',
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        defaultSortColumn: treeColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      final TreeTableState<TestData> state = tester.state(find.byWidget(table));
      final tree = state.tableController.dataRoots[0];
      expect(tree.children[0].name, equals('Bar'));
      expect(tree.children[0].children[0].name, equals('Baz'));
      expect(tree.children[0].children[1].name, equals('Crackle'));
      expect(tree.children[0].children[2].name, equals('Pop'));
      expect(tree.children[0].children[3].name, equals('Qux'));
      expect(tree.children[0].children[4].name, equals('Snap'));
      expect(tree.children[1].name, equals('Baz'));
      expect(tree.children[2].name, equals('Qux'));
    });

    testWidgets('sorts data by column', (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [
          _NumberColumn(),
          treeColumn,
        ],
        dataRoots: [tree1],
        dataKey: 'test-data',
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        defaultSortColumn: treeColumn,
        defaultSortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      final TreeTableState<TestData> state = tester.state(find.byWidget(table));
      expect(state.tableController.columnWidths![0], equals(400));
      expect(state.tableController.columnWidths![1], equals(81));
      final tree = state.tableController.dataRoots[0];
      expect(tree.children[0].name, equals('Bar'));
      expect(tree.children[0].children[0].name, equals('Baz'));
      expect(tree.children[0].children[1].name, equals('Crackle'));
      expect(tree.children[0].children[2].name, equals('Pop'));
      expect(tree.children[0].children[4].name, equals('Snap'));
      expect(tree.children[1].name, equals('Baz'));
      expect(tree.children[2].name, equals('Qux'));

      // Reverse the sort direction.
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(tree.children[2].name, equals('Bar'));
      expect(tree.children[2].children[4].name, equals('Baz'));
      expect(tree.children[2].children[3].name, equals('Crackle'));
      expect(tree.children[2].children[2].name, equals('Pop'));
      expect(tree.children[2].children[1].name, equals('Qux'));
      expect(tree.children[2].children[0].name, equals('Snap'));
      expect(tree.children[1].name, equals('Baz'));
      expect(tree.children[0].name, equals('Qux'));

      // Change the sort column.
      await tester.tap(find.text('Number'));
      await tester.pumpAndSettle();
      expect(tree.children[0].name, equals('Bar'));
      expect(tree.children[0].children[0].name, equals('Baz'));
      expect(tree.children[0].children[1].name, equals('Qux'));
      expect(tree.children[0].children[2].name, equals('Snap'));
      expect(tree.children[0].children[3].name, equals('Pop'));
      expect(tree.children[0].children[4].name, equals('Crackle'));
      expect(tree.children[1].name, equals('Qux'));
      expect(tree.children[2].name, equals('Baz'));
    });

    group('keyboard navigation', () {
      late TestData data;
      late TreeTable<TestData> table;

      setUp(() {
        data = TestData('Foo', 0);
        data.addAllChildren([
          TestData('Bar', 1),
          TestData('Crackle', 5),
        ]);

        table = TreeTable<TestData>(
          columns: [
            _NumberColumn(),
            treeColumn,
          ],
          dataRoots: [data],
          dataKey: 'test-data',
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: treeColumn,
          defaultSortDirection: SortDirection.ascending,
        );
      });

      testWidgets(
        'selection changes with up/down arrow keys',
        (WidgetTester tester) async {
          data.expand();
          await tester.pumpWidget(wrap(table));
          await tester.pumpAndSettle();

          final TreeTableState state = tester.state(find.byWidget(table));
          state.focusNode!.requestFocus();
          await tester.pumpAndSettle();

          expect(state.widget.selectionNotifier.value.node, equals(null));

          // the root is selected by default when there is no selection. Pressing
          // arrowDown should take us to the first child, Bar
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(
            state.widget.selectionNotifier.value.node,
            equals(data.children[0]),
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();

          expect(state.widget.selectionNotifier.value.node, equals(data.root));
        },
      );

      testWidgets(
        'selection changes with left/right arrow keys',
        (WidgetTester tester) async {
          await tester.pumpWidget(wrap(table));
          await tester.pumpAndSettle();

          final TreeTableState state = tester.state(find.byWidget(table));
          state.focusNode!.requestFocus();
          await tester.pumpAndSettle();

          // left arrow on collapsed node with no parent should succeed but have
          // no effect.
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();

          expect(state.widget.selectionNotifier.value.node, equals(data.root));
          expect(
            state.widget.selectionNotifier.value.node!.isExpanded,
            isFalse,
          );

          // Expand root and navigate down twice
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();

          expect(
            state.widget.selectionNotifier.value.node,
            equals(data.root.children[1]),
          );

          // Back to parent
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();

          expect(state.widget.selectionNotifier.value.node, equals(data.root));
          expect(state.widget.selectionNotifier.value.node!.isExpanded, isTrue);
        },
      );
    });

    testWidgets(
      'properly colors rows with alternating colors',
      (WidgetTester tester) async {
        final data = TestData('Foo', 0)
          ..children.addAll([
            TestData('Bar', 1)
              ..children.addAll([
                TestData('Baz', 2),
                TestData('Qux', 3),
                TestData('Snap', 4),
              ]),
            TestData('Crackle', 5),
          ])
          ..expandCascading();
        final table = TreeTable<TestData>(
          columns: [
            _NumberColumn(),
            treeColumn,
          ],
          dataRoots: [data],
          dataKey: 'test-data',
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          defaultSortColumn: treeColumn,
          defaultSortDirection: SortDirection.ascending,
        );

        final fooFinder = find.byKey(const Key('Foo'));
        final barFinder = find.byKey(const Key('Bar'));
        final bazFinder = find.byKey(const Key('Baz'));
        final quxFinder = find.byKey(const Key('Qux'));
        final snapFinder = find.byKey(const Key('Snap'));
        final crackleFinder = find.byKey(const Key('Crackle'));

        // Expected values returned through accessing Color.value property.
        const color1Value = 4294111476;
        const color2Value = 4294967295;
        const rowSelectedColorValue = 4294967295;

        await tester.pumpWidget(wrap(table));
        await tester.pumpAndSettle();
        expect(tree1.isExpanded, true);

        expect(fooFinder, findsOneWidget);
        expect(barFinder, findsOneWidget);
        expect(bazFinder, findsOneWidget);
        expect(quxFinder, findsOneWidget);
        expect(snapFinder, findsOneWidget);
        expect(crackleFinder, findsOneWidget);
        TableRow fooRow = tester.widget(fooFinder);
        TableRow barRow = tester.widget(barFinder);
        final TableRow bazRow = tester.widget(bazFinder);
        final TableRow quxRow = tester.widget(quxFinder);
        final TableRow snapRow = tester.widget(snapFinder);
        TableRow crackleRow = tester.widget(crackleFinder);

        expect(fooRow.backgroundColor!.value, equals(color1Value));
        expect(barRow.backgroundColor!.value, equals(color2Value));
        expect(bazRow.backgroundColor!.value, equals(color1Value));
        expect(quxRow.backgroundColor!.value, equals(color2Value));
        expect(snapRow.backgroundColor!.value, equals(color1Value));
        expect(crackleRow.backgroundColor!.value, equals(color2Value));

        await tester.tap(barFinder);
        await tester.pumpAndSettle();
        expect(fooFinder, findsOneWidget);
        expect(barFinder, findsOneWidget);
        expect(bazFinder, findsNothing);
        expect(quxFinder, findsNothing);
        expect(snapFinder, findsNothing);
        expect(crackleFinder, findsOneWidget);
        fooRow = tester.widget(fooFinder);
        barRow = tester.widget(barFinder);
        crackleRow = tester.widget(crackleFinder);

        expect(fooRow.backgroundColor!.value, equals(color1Value));
        // [barRow] has the rowSelected color after being tapped.
        expect(barRow.backgroundColor!.value, equals(rowSelectedColorValue));
        // [crackleRow] has a different background color after collapsing previous
        // row (Bar).
        expect(crackleRow.backgroundColor!.value, equals(color1Value));
      },
    );

    test('fails when TreeColumn is not in column list', () {
      expect(
        () {
          TreeTable<TestData>(
            columns: const [],
            dataRoots: [tree1],
            dataKey: 'test-data',
            treeColumn: treeColumn,
            keyFactory: (d) => Key(d.name),
            defaultSortColumn: treeColumn,
            defaultSortDirection: SortDirection.ascending,
          );
        },
        throwsAssertionError,
      );
    });
  });
}

class TestData extends TreeNode<TestData> {
  TestData(this.name, this.number);

  final String name;
  final int number;

  @override
  String toString() => '$name - $number';

  @override
  TestData shallowCopy() {
    throw UnimplementedError(
      'This method is not implemented. Implement if you '
      'need to call `shallowCopy` on an instance of this class.',
    );
  }
}

class PinnableTestData implements PinnableListEntry {
  PinnableTestData({
    required this.name,
    required this.enabled,
  });

  final String name;
  final bool enabled;

  @override
  bool get pinToTop => enabled;

  @override
  String toString() => name;
}

class _NameColumn extends TreeColumnData<TestData> {
  _NameColumn() : super('Name');

  @override
  String getValue(TestData dataObject) => dataObject.name;

  @override
  bool get supportsSorting => true;
}

class _NumberColumn extends ColumnData<TestData> {
  _NumberColumn()
      : super(
          'Number',
          fixedWidthPx: 400.0,
        );

  @override
  int getValue(TestData dataObject) => dataObject.number;

  @override
  bool get supportsSorting => true;
}

class _FlatNameColumn extends ColumnData<TestData> {
  _FlatNameColumn()
      : super(
          'FlatName',
          fixedWidthPx: 300.0,
        );

  @override
  String getValue(TestData dataObject) => dataObject.name;

  @override
  bool get supportsSorting => true;
}

class _PinnableFlatNameColumn extends ColumnData<PinnableTestData> {
  _PinnableFlatNameColumn()
      : super(
          'FlatName',
          fixedWidthPx: 300.0,
        );

  @override
  String getValue(PinnableTestData dataObject) => dataObject.name;

  @override
  bool get supportsSorting => true;
}

class _CombinedColumn extends ColumnData<TestData> {
  _CombinedColumn()
      : super(
          'Name & Number',
          fixedWidthPx: 400.0,
        );

  @override
  String getValue(TestData dataObject) =>
      '${dataObject.name} ${dataObject.number}';
}

class _WideColumn extends ColumnData<TestData> {
  _WideColumn() : super.wide('Wide Column');

  @override
  String getValue(TestData dataObject) =>
      '${dataObject.name} ${dataObject.number} bla bla bla bla bla bla bla bla';
}

class _WideMinWidthColumn extends ColumnData<TestData> {
  _WideMinWidthColumn()
      : super.wide(
          'Wide MinWidth Column',
          minWidthPx: scaleByFontFactor(100.0),
        );

  @override
  String getValue(TestData dataObject) =>
      '${dataObject.name} ${dataObject.number} with min width';
}

class _VeryWideMinWidthColumn extends ColumnData<TestData> {
  _VeryWideMinWidthColumn()
      : super.wide(
          'Very Wide MinWidth Column',
          minWidthPx: scaleByFontFactor(160.0),
        );

  @override
  String getValue(TestData dataObject) =>
      '${dataObject.name} ${dataObject.number} with min width';
}
