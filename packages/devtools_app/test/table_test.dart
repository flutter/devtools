import 'package:devtools_app/src/table.dart';
import 'package:devtools_app/src/table_data.dart';
import 'package:devtools_app/src/trees.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/wrappers.dart';

void main() {
  group('FlatTable view', () {
    List<TestData> flatData;
    ColumnData<TestData> flatNameColumn;

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
        keyFactory: (d) => Key(d.name),
        onItemSelected: noop,
        sortColumn: flatNameColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      expect(find.byWidget(table), findsOneWidget);
      final FlatTableState state = tester.state(find.byWidget(table));
      final columnWidths = state.computeColumnWidths(1000);
      expect(columnWidths.length, 1);
      expect(columnWidths.first, 300);
      expect(find.byKey(const Key('empty')), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'displays with full content', const Size(800.0, 1200.0),
        (WidgetTester tester) async {
      final table = FlatTable<TestData>(
        columns: [
          flatNameColumn,
          _NumberColumn(),
        ],
        data: flatData,
        onItemSelected: noop,
        keyFactory: (d) => Key(d.name),
        sortColumn: flatNameColumn,
        sortDirection: SortDirection.ascending,
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
    });

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
        onItemSelected: noop,
        keyFactory: (d) => Key(d.name),
        sortColumn: flatNameColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      final FlatTableState state = tester.state(find.byWidget(table));
      final data = state.data;
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
        onItemSelected: noop,
        keyFactory: (d) => Key(d.name),
        sortColumn: flatNameColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      final FlatTableState state = tester.state(find.byWidget(table));
      final data = state.data;
      expect(data[0].name, equals('Bar'));
      expect(data[1].name, equals('Baz'));
      expect(data[2].name, equals('Baz'));
      expect(data[3].name, equals('Crackle'));
      expect(data[4].name, equals('Foo'));
      expect(data[5].name, equals('Pop'));
      expect(data[6].name, equals('Qux'));
      expect(data[7].name, equals('Qux'));
      expect(data[8].name, equals('Snap'));

      // Reverse the sort direction.
      await tester.tap(find.text('FlatName'));
      await tester.pumpAndSettle();

      expect(data[8].name, equals('Bar'));
      expect(data[7].name, equals('Baz'));
      expect(data[6].name, equals('Baz'));
      expect(data[5].name, equals('Crackle'));
      expect(data[4].name, equals('Foo'));
      expect(data[3].name, equals('Pop'));
      expect(data[2].name, equals('Qux'));
      expect(data[1].name, equals('Qux'));
      expect(data[0].name, equals('Snap'));

      // Change the sort column.
      await tester.tap(find.text('Number'));
      await tester.pumpAndSettle();
      expect(data[0].name, equals('Foo'));
      expect(data[1].name, equals('Bar'));
      expect(data[2].name, equals('Baz'));
      expect(data[3].name, equals('Qux'));
      expect(data[4].name, equals('Snap'));
      expect(data[5].name, equals('Pop'));
      expect(data[6].name, equals('Crackle'));
      expect(data[7].name, equals('Baz'));
      expect(data[8].name, equals('Qux'));
    });

    testWidgets('displays with many columns', (WidgetTester tester) async {
      final table = FlatTable<TestData>(
        columns: [
          _NumberColumn(),
          _CombinedColumn(),
          flatNameColumn,
          _CombinedColumn(),
        ],
        data: flatData,
        onItemSelected: noop,
        keyFactory: (data) => Key(data.name),
        sortColumn: flatNameColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(
        SizedBox(
          width: 200.0,
          height: 200.0,
          child: table,
        ),
      ));
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
        onItemSelected: noop,
        keyFactory: (data) => Key(data.name),
        sortColumn: flatNameColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(
        SizedBox(
          width: 800.0,
          height: 200.0,
          child: table,
        ),
      ));
      expect(find.byWidget(table), findsOneWidget);
      {
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        final columnWidths = state.computeColumnWidths(800.0);
        expect(columnWidths.length, equals(3));
        expect(columnWidths[0], equals(300.0));
        expect(columnWidths[1], equals(400.0));
        expect(columnWidths[2], equals(36.0));
      }

      // TODO(jacobr): add a golden image test.

      await tester.pumpWidget(wrap(
        SizedBox(
          width: 200.0,
          height: 200.0,
          child: table,
        ),
      ));

      {
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        final columnWidths = state.computeColumnWidths(200.0);
        expect(columnWidths.length, equals(3));
        expect(columnWidths[0], equals(300.0)); // Fixed width column.
        expect(columnWidths[1], equals(400.0)); // Fixed width column.
        expect(columnWidths[2], equals(0.0)); // Variable width column.
      }

      // TODO(jacobr): add a golden image test.
    });

    testWidgets('displays with multiple wide columns',
        (WidgetTester tester) async {
      final table = FlatTable<TestData>(
        columns: [
          flatNameColumn,
          _WideMinWidthColumn(),
          _NumberColumn(),
          _WideColumn(),
        ],
        data: flatData,
        onItemSelected: noop,
        keyFactory: (data) => Key(data.name),
        sortColumn: flatNameColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(
        SizedBox(
          width: 1000.0,
          height: 200.0,
          child: table,
        ),
      ));
      expect(find.byWidget(table), findsOneWidget);
      {
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        final columnWidths = state.computeColumnWidths(1000.0);
        expect(columnWidths.length, equals(4));
        expect(columnWidths[0], equals(300.0)); // Fixed width column.
        expect(columnWidths[1], equals(110.0)); // Min width wide column
        expect(columnWidths[2], equals(400.0)); // Fixed width column.
        expect(columnWidths[3], equals(110.0)); // Variable width wide column.
      }

      await tester.pumpWidget(wrap(
        SizedBox(
          width: 200.0,
          height: 200.0,
          child: table,
        ),
      ));
      {
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        final columnWidths = state.computeColumnWidths(200.0);
        expect(columnWidths.length, equals(4));
        expect(columnWidths[0], equals(300.0)); // Fixed width column.
        expect(columnWidths[1], equals(100.0)); // Min width wide column
        expect(columnWidths[2], equals(400.0)); // Fixed width column.
        expect(columnWidths[3], equals(0.0)); // Variable width wide column.
      }
    });

    testWidgets('displays with multiple min width wide columns',
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
        onItemSelected: noop,
        keyFactory: (data) => Key(data.name),
        sortColumn: flatNameColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(
        SizedBox(
          width: 1501.0,
          height: 200.0,
          child: table,
        ),
      ));
      expect(find.byWidget(table), findsOneWidget);
      {
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        final columnWidths = state.computeColumnWidths(1501.0);
        expect(columnWidths.length, equals(5));
        expect(columnWidths[0], equals(300.0)); // Fixed width column.
        expect(columnWidths[1], equals(235.0)); // Min width wide column
        expect(
            columnWidths[2], equals(235.0)); // Very wide min width wide column
        expect(columnWidths[3], equals(400.0)); // Fixed width column.
        expect(columnWidths[4], equals(235.0)); // Variable width wide column.
      }

      await tester.pumpWidget(wrap(
        SizedBox(
          width: 1200.0,
          height: 200.0,
          child: table,
        ),
      ));
      expect(find.byWidget(table), findsOneWidget);
      {
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        final columnWidths = state.computeColumnWidths(1200.0);
        expect(columnWidths.length, equals(5));
        expect(columnWidths[0], equals(300.0)); // Fixed width column.
        expect(columnWidths[1], equals(122.0)); // Min width wide column
        expect(
            columnWidths[2], equals(160.0)); // Very wide min width wide column
        expect(columnWidths[3], equals(400.0)); // Fixed width column.
        expect(columnWidths[4], equals(122.0)); // Variable width wide column.
      }

      await tester.pumpWidget(wrap(
        SizedBox(
          width: 1000.0,
          height: 200.0,
          child: table,
        ),
      ));
      expect(find.byWidget(table), findsOneWidget);
      {
        final FlatTableState<TestData> state =
            tester.state(find.byWidget(table));
        final columnWidths = state.computeColumnWidths(1000.0);
        expect(columnWidths.length, equals(5));
        expect(columnWidths[0], equals(300.0)); // Fixed width column.
        expect(columnWidths[1], equals(100.0)); // Min width wide column
        expect(
            columnWidths[2], equals(160.0)); // Very wide min width wide column
        expect(columnWidths[3], equals(400.0)); // Fixed width column.
        expect(columnWidths[4], equals(0.0)); // Variable width wide column.
      }
    });

    testWidgets('can select an item', (WidgetTester tester) async {
      TestData selected;
      final testData = TestData('empty', 0);
      const key = Key('empty');
      final table = FlatTable<TestData>(
        columns: [flatNameColumn],
        data: [testData],
        keyFactory: (d) => Key(d.name),
        onItemSelected: (item) => selected = item,
        sortColumn: flatNameColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      expect(find.byWidget(table), findsOneWidget);
      expect(find.byKey(key), findsOneWidget);
      expect(selected, isNull);
      await tester.tap(find.byKey(key));
      expect(selected, testData);
    });

    test('fails with no data', () {
      expect(
        () {
          FlatTable<TestData>(
            columns: [flatNameColumn],
            data: null,
            keyFactory: (d) => Key(d.name),
            onItemSelected: noop,
            sortColumn: flatNameColumn,
            sortDirection: SortDirection.ascending,
          );
        },
        throwsAssertionError,
      );
    });

    test('fails when a TreeNode cannot provide a key', () {
      expect(() {
        FlatTable<TestData>(
          columns: [flatNameColumn],
          data: flatData,
          keyFactory: null,
          onItemSelected: noop,
          sortColumn: flatNameColumn,
          sortDirection: SortDirection.ascending,
        );
      }, throwsAssertionError);
    });
  });

  group('TreeTable view', () {
    TestData tree1;
    TestData tree2;
    TreeColumnData<TestData> treeColumn;

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
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      expect(find.byWidget(table), findsOneWidget);
      expect(find.byKey(const Key('empty')), findsOneWidget);
    });

    testWidgets('displays with multiple data roots',
        (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [treeColumn],
        dataRoots: [tree1, tree2],
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.ascending,
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
    });

    testWidgets('displays when widget changes dataRoots',
        (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [treeColumn],
        dataRoots: [tree1, tree2],
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.ascending,
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
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.descending,
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
    });

    testWidgetsWithWindowSize(
        'displays with tree column first', const Size(800.0, 1200.0),
        (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [
          treeColumn,
          _NumberColumn(),
        ],
        dataRoots: [tree1],
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.descending,
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
    });

    testWidgets('displays with many columns', (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [
          _NumberColumn(),
          _CombinedColumn(),
          treeColumn,
          _CombinedColumn(),
        ],
        dataRoots: [tree1],
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(
        SizedBox(
          width: 200.0,
          height: 200.0,
          child: table,
        ),
      ));
      expect(find.byWidget(table), findsOneWidget);
    });

    testWidgets('properly collapses and expands the tree',
        (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [
          _NumberColumn(),
          treeColumn,
        ],
        dataRoots: [tree1],
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.ascending,
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
    });

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
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      final TreeTableState state = tester.state(find.byWidget(table));
      final tree = state.dataRoots[0];
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
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.ascending,
      );
      await tester.pumpWidget(wrap(table));
      final TreeTableState state = tester.state(find.byWidget(table));
      expect(state.columnWidths[0], equals(400));
      expect(state.columnWidths[1], equals(1000));
      final tree = state.dataRoots[0];
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
      TestData data;
      TreeTable<TestData> table;

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
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          sortColumn: treeColumn,
          sortDirection: SortDirection.ascending,
        );
      });

      testWidgets('selection changes with up/down arrow keys',
          (WidgetTester tester) async {
        data.expand();
        await tester.pumpWidget(wrap(table));
        await tester.pumpAndSettle();

        final TreeTableState state = tester.state(find.byWidget(table));
        state.focusNode.requestFocus();
        await tester.pumpAndSettle();

        expect(state.selectionNotifier.value.node, equals(null));

        // the root is selected by default when there is no selection. Pressing
        // arrowDown should take us to the first child, Bar
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(state.selectionNotifier.value.node, equals(data.children[0]));

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        expect(state.selectionNotifier.value.node, equals(data.root));
      });

      testWidgets('selection changes with left/right arrow keys',
          (WidgetTester tester) async {
        await tester.pumpWidget(wrap(table));
        await tester.pumpAndSettle();

        final TreeTableState state = tester.state(find.byWidget(table));
        state.focusNode.requestFocus();
        await tester.pumpAndSettle();

        // left arrow on collapsed node with no parent should succeed but have
        // no effect.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        expect(state.selectionNotifier.value.node, equals(data.root));
        expect(state.selectionNotifier.value.node.isExpanded, isFalse);

        // Expand root and navigate down twice
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        expect(
          state.selectionNotifier.value.node,
          equals(data.root.children[1]),
        );

        // Back to parent
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        expect(state.selectionNotifier.value.node, equals(data.root));
        expect(state.selectionNotifier.value.node.isExpanded, isTrue);
      });
    });

    testWidgets('properly colors rows with alternating colors',
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
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
        sortColumn: treeColumn,
        sortDirection: SortDirection.ascending,
      );

      final fooFinder = find.byKey(const Key('Foo'));
      final barFinder = find.byKey(const Key('Bar'));
      final bazFinder = find.byKey(const Key('Baz'));
      final quxFinder = find.byKey(const Key('Qux'));
      final snapFinder = find.byKey(const Key('Snap'));
      final crackleFinder = find.byKey(const Key('Crackle'));

      // Expected values returned through accessing Color.value property.
      const color1Value = 4293848814;
      const color2Value = 4294638330;
      const rowSelectedColorValue = 4278285762;

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

      expect(fooRow.backgroundColor.value, equals(color1Value));
      expect(barRow.backgroundColor.value, equals(color2Value));
      expect(bazRow.backgroundColor.value, equals(color1Value));
      expect(quxRow.backgroundColor.value, equals(color2Value));
      expect(snapRow.backgroundColor.value, equals(color1Value));
      expect(crackleRow.backgroundColor.value, equals(color2Value));

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

      expect(fooRow.backgroundColor.value, equals(color1Value));
      // [barRow] has the rowSelected color after being tapped.
      expect(barRow.backgroundColor.value, equals(rowSelectedColorValue));
      // [crackleRow] has a different background color after collapsing previous
      // row (Bar).
      expect(crackleRow.backgroundColor.value, equals(color1Value));
    });

    test('fails with no data', () {
      expect(
        () {
          TreeTable<TestData>(
            columns: [treeColumn],
            dataRoots: null,
            treeColumn: treeColumn,
            keyFactory: (d) => Key(d.name),
            sortColumn: treeColumn,
            sortDirection: SortDirection.ascending,
          );
        },
        throwsAssertionError,
      );
    });

    test('fails when a TreeNode cannot provide a key', () {
      expect(() {
        TreeTable<TestData>(
          columns: [treeColumn],
          dataRoots: [tree1],
          treeColumn: treeColumn,
          keyFactory: null,
          sortColumn: treeColumn,
          sortDirection: SortDirection.ascending,
        );
      }, throwsAssertionError);
    });

    test('fails when there is no TreeColumn', () {
      expect(() {
        TreeTable<TestData>(
          columns: [treeColumn],
          dataRoots: [tree1],
          treeColumn: null,
          keyFactory: (d) => Key(d.name),
          sortColumn: treeColumn,
          sortDirection: SortDirection.ascending,
        );
      }, throwsAssertionError);

      expect(() {
        TreeTable<TestData>(
          columns: const [],
          dataRoots: [tree1],
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
          sortColumn: treeColumn,
          sortDirection: SortDirection.ascending,
        );
      }, throwsAssertionError);
    });
  });
}

class TestData extends TreeNode<TestData> {
  TestData(this.name, this.number);

  final String name;
  final int number;

  @override
  String toString() => '$name - $number';
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
          minWidthPx: 100.0,
        );

  @override
  String getValue(TestData dataObject) =>
      '${dataObject.name} ${dataObject.number} with min width';
}

class _VeryWideMinWidthColumn extends ColumnData<TestData> {
  _VeryWideMinWidthColumn()
      : super.wide(
          'Very Wide MinWidth Column',
          minWidthPx: 160.0,
        );

  @override
  String getValue(TestData dataObject) =>
      '${dataObject.name} ${dataObject.number} with min width';
}

void noop(TestData data) {}
