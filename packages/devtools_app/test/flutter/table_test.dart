import 'package:devtools_app/src/flutter/table.dart';
import 'package:devtools_app/src/table_data.dart';
import 'package:devtools_app/src/trees.dart';
import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  group('FlatTable view', () {
    List<TestData> flatData;

    setUp(() {
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
        columns: [_FlatNameColumn()],
        data: [TestData('empty', 0)],
        keyFactory: (d) => Key(d.name),
        onItemSelected: noop,
      );
      await tester.pumpWidget(wrap(table));
      expect(find.byWidget(table), findsOneWidget);
      expect(find.byKey(const Key('empty')), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'displays with tree column first', const Size(800.0, 1200.0),
        (WidgetTester tester) async {
      final table = FlatTable<TestData>(
        columns: [
          _FlatNameColumn(),
          _NumberColumn(),
        ],
        data: flatData,
        onItemSelected: noop,
        keyFactory: (d) => Key(d.name),
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
      final table = FlatTable<TestData>(
        columns: [
          _NumberColumn(),
          _CombinedColumn(),
          _FlatNameColumn(),
          _CombinedColumn(),
        ],
        data: flatData,
        onItemSelected: noop,
        keyFactory: (data) => Key(data.name),
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

    testWidgets('can select an item', (WidgetTester tester) async {
      TestData selected;
      final testData = TestData('empty', 0);
      const key = Key('empty');
      final table = FlatTable<TestData>(
        columns: [_FlatNameColumn()],
        data: [testData],
        keyFactory: (d) => Key(d.name),
        onItemSelected: (item) => selected = item,
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
            columns: [_FlatNameColumn()],
            data: null,
            keyFactory: (d) => Key(d.name),
            onItemSelected: noop,
          );
        },
        throwsAssertionError,
      );
    });

    test('fails when a TreeNode cannot provide a key', () {
      expect(() {
        FlatTable<TestData>(
          columns: [_FlatNameColumn()],
          data: flatData,
          keyFactory: null,
          onItemSelected: noop,
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
          TestData('Baz', 6),
          TestData('Qux', 7),
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
      );

      final fooFinder = find.byKey(const Key('Foo'));
      final barFinder = find.byKey(const Key('Bar'));
      final bazFinder = find.byKey(const Key('Baz'));
      final quxFinder = find.byKey(const Key('Qux'));
      final snapFinder = find.byKey(const Key('Snap'));
      final crackleFinder = find.byKey(const Key('Crackle'));

      // Expected values returned through accessing Color.value property.
      const color1Value = 4293585900;
      const color2Value = 4294638330;

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
      expect(barRow.backgroundColor.value, equals(color2Value));
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
        );
      }, throwsAssertionError);

      expect(() {
        TreeTable<TestData>(
          columns: const [],
          dataRoots: [tree1],
          treeColumn: treeColumn,
          keyFactory: (d) => Key(d.name),
        );
      }, throwsAssertionError);
    });
  });
}

class TestData extends TreeNode<TestData> {
  TestData(this.name, this.number);
  final String name;
  final int number;
}

class _NameColumn extends TreeColumnData<TestData> {
  _NameColumn() : super('Name');

  @override
  String getValue(TestData dataObject) => dataObject.name;
}

class _NumberColumn extends ColumnData<TestData> {
  _NumberColumn() : super('Name');

  @override
  String getValue(TestData dataObject) => 'dataObject.number';

  @override
  double get fixedWidthPx => 400.0;
}

class _FlatNameColumn extends ColumnData<TestData> {
  _FlatNameColumn() : super('Name');

  @override
  String getValue(TestData dataObject) => dataObject.name;

  @override
  double get fixedWidthPx => 300.0;
}

class _CombinedColumn extends ColumnData<TestData> {
  _CombinedColumn() : super('Name & Number');

  @override
  String getValue(TestData dataObject) =>
      '${dataObject.name} ${dataObject.number}';

  @override
  double get fixedWidthPx => 400.0;
}

void noop(TestData data) {}
