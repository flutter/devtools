// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../charts/treemap.dart';
import '../table.dart';
import '../table_data.dart';
import '../utils.dart';

class CodeSizeTable extends StatelessWidget {
  factory CodeSizeTable({@required rootNode}) {
    final treeColumn = _NameColumn(currentRootLevel: rootNode.level);
    final sortColumn = _SizeColumn();
    final columns = List<ColumnData<TreemapNode>>.unmodifiable([
      treeColumn,
      sortColumn,
      _SizePercentageColumn(totalSize: rootNode.root.byteSize),
    ]);

    return CodeSizeTable._(
      rootNode,
      treeColumn,
      sortColumn,
      columns,
    );
  }

  const CodeSizeTable._(
    this.rootNode,
    this.treeColumn,
    this.sortColumn,
    this.columns,
  );

  final TreemapNode rootNode;

  final TreeColumnData<TreemapNode> treeColumn;
  final ColumnData<TreemapNode> sortColumn;
  final List<ColumnData<TreemapNode>> columns;

  @override
  Widget build(BuildContext context) {
    return TreeTable<TreemapNode>(
      dataRoots: rootNode.children,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (node) => PageStorageKey<String>(node.name),
      sortColumn: sortColumn,
      sortDirection: SortDirection.descending,
    );
  }
}

class _NameColumn extends TreeColumnData<TreemapNode> {
  _NameColumn({@required this.currentRootLevel}) : super('Library or Class');

  final int currentRootLevel;

  @override
  dynamic getValue(TreemapNode dataObject) => dataObject.name;

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(TreemapNode dataObject) => dataObject.displayText();

  @override
  double getNodeIndentPx(TreemapNode dataObject) {
    final relativeLevel = dataObject.level - currentRootLevel - 1;
    return relativeLevel * TreeColumnData.treeToggleWidth;
  }
}

class _SizeColumn extends ColumnData<TreemapNode> {
  _SizeColumn() : super('Size', alignment: ColumnAlignment.right);

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
      : super('% of Total Size', alignment: ColumnAlignment.right);

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
