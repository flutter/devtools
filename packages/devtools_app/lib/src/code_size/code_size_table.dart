import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/treemap.dart';
import '../table.dart';
import '../table_data.dart';
import '../utils.dart';
import 'code_size_controller.dart';

class TreemapTreeTable extends StatefulWidget {
  const TreemapTreeTable();

  @override
  TreemapTreeTableState createState() => TreemapTreeTableState();
}

class TreemapTreeTableState extends State<TreemapTreeTable>
    with AutoDisposeMixin {
  TreeColumnData<TreemapNode> treeColumn =
      _LibraryRefColumn(currentRootLevel: 0);
  final List<ColumnData<TreemapNode>> columns = [];

  CodeSizeController controller;

  TreemapNode currentRoot;
  @override
  void initState() {
    super.initState();
    setupColumns();
  }

  void setupColumns() {
    columns.addAll([
      treeColumn,
      _ShallowSizeColumn(),
      _SizePercentageColumn(totalSize: 0),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<CodeSizeController>(context);
    if (newController == controller) return;
    controller = newController;

    onCurrentRootChanged();

    addAutoDisposeListener(controller.currentRoot, onCurrentRootChanged);
  }

  void onCurrentRootChanged() {
    setState(() {
      currentRoot = controller.currentRoot.value;
      treeColumn = _LibraryRefColumn(currentRootLevel: currentRoot.level);
      columns[0] = treeColumn;
      columns[2] =
          _SizePercentageColumn(totalSize: controller.topRoot.byteSize);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TreeTable<TreemapNode>(
      dataRoots: currentRoot.children,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (node) => PageStorageKey<String>(node.name),
      sortColumn: columns[1],
      sortDirection: SortDirection.descending,
    );
  }
}

class _LibraryRefColumn extends TreeColumnData<TreemapNode> {
  _LibraryRefColumn({@required this.currentRootLevel})
      : super('Library or Class');

  final int currentRootLevel;

  @override
  dynamic getValue(TreemapNode dataObject) => dataObject.name;

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(TreemapNode dataObject) => dataObject.displayText();

  @override
  double get fixedWidthPx => 250.0;

  @override
  double getNodeIndentPx(TreemapNode dataObject) {
    final relativeLevel = dataObject.level - currentRootLevel - 1;
    return relativeLevel * TreeColumnData.treeToggleWidth;
  }
}

class _ShallowSizeColumn extends ColumnData<TreemapNode> {
  _ShallowSizeColumn() : super('Shallow', alignment: ColumnAlignment.right);

  @override
  dynamic getValue(TreemapNode dataObject) => dataObject.byteSize;

  @override
  String getDisplayValue(TreemapNode dataObject) =>
      prettyPrintBytes(dataObject.byteSize, includeUnit: true);

  @override
  bool get supportsSorting => true;

  @override
  int compare(TreemapNode a, TreemapNode b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 100.0;
}

class _SizePercentageColumn extends ColumnData<TreemapNode> {
  _SizePercentageColumn({@required this.totalSize})
      : super('% of Total', alignment: ColumnAlignment.right);

  final int totalSize;

  @override
  dynamic getValue(TreemapNode dataObject) =>
      (dataObject.byteSize / totalSize) * 100;

  @override
  String getDisplayValue(TreemapNode dataObject) =>
      '${getValue(dataObject).toStringAsFixed(2)} %';

  @override
  bool get supportsSorting => true;

  @override
  int compare(TreemapNode a, TreemapNode b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 100.0;
}
