import 'package:devtools_app/src/flutter/table.dart';
import 'package:devtools_app/src/table_data.dart';
import 'package:devtools_app/src/trees.dart';
import 'package:flutter/material.dart';
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
    TestData tree;
    TreeColumnData<TestData> treeColumn;

    setUp(() {
      treeColumn = _NameColumn();
      tree = TestData('Foo', 0)
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
        ]);
      tree.expandCascading();
    });

    testWidgets('displays with simple content', (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [treeColumn],
        data: TestData('empty', 0),
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
      );
      await tester.pumpWidget(wrap(table));
      expect(find.byWidget(table), findsOneWidget);
      expect(find.byKey(const Key('empty')), findsOneWidget);
    });

    testWidgetsWithWindowSize(
        'displays with tree column first', const Size(800.0, 1200.0),
        (WidgetTester tester) async {
      final table = TreeTable<TestData>(
        columns: [
          treeColumn,
          _NumberColumn(),
        ],
        data: tree,
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
        data: tree,
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
        data: tree,
        treeColumn: treeColumn,
        keyFactory: (d) => Key(d.name),
      );
      await tester.pumpWidget(wrap(table));
      await tester.pumpAndSettle();
      expect(tree.isExpanded, true);
      await tester.tap(find.byKey(const Key('Foo')));
      await tester.pumpAndSettle();
      expect(tree.isExpanded, false);
      await tester.tap(find.byKey(const Key('Foo')));
      await tester.pumpAndSettle();
      expect(tree.isExpanded, true);
      await tester.tap(find.byKey(const Key('Bar')));
      await tester.pumpAndSettle();
      expect(tree.children[0].isExpanded, false);
    });

    test('fails with no data', () {
      expect(
        () {
          TreeTable<TestData>(
            columns: [treeColumn],
            data: null,
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
          data: tree,
          treeColumn: treeColumn,
          keyFactory: null,
        );
      }, throwsAssertionError);
    });

    test('fails when there is no TreeColumn', () {
      expect(() {
        TreeTable<TestData>(
          columns: [treeColumn],
          data: tree,
          treeColumn: null,
          keyFactory: (d) => Key(d.name),
        );
      }, throwsAssertionError);

      expect(() {
        TreeTable<TestData>(
          columns: const [],
          data: tree,
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
