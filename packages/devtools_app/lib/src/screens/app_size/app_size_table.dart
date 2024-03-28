// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/charts/treemap.dart';
import '../../shared/primitives/byte_utils.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/ui/colors.dart';
import 'app_size_controller.dart';

class AppSizeAnalysisTable extends StatelessWidget {
  factory AppSizeAnalysisTable({
    required TreemapNode rootNode,
    required AppSizeController controller,
  }) {
    final treeColumn = _NameColumn(
      currentRootLevel: controller.isDeferredApp.value
          ? rootNode.children.first.level
          : rootNode.level,
    );
    final sizeColumn = _SizeColumn();
    final columns = List<ColumnData<TreemapNode>>.unmodifiable([
      treeColumn,
      sizeColumn,
      _SizePercentageColumn(
        totalSize: controller.isDeferredApp.value
            ? rootNode.children[0].root.byteSize
            : rootNode.root.byteSize,
      ),
    ]);

    return AppSizeAnalysisTable._(
      rootNode,
      treeColumn,
      sizeColumn,
      columns,
      controller,
    );
  }

  const AppSizeAnalysisTable._(
    this.rootNode,
    this.treeColumn,
    this.sortColumn,
    this.columns,
    this.controller,
  );

  final TreemapNode rootNode;

  final TreeColumnData<TreemapNode> treeColumn;
  final ColumnData<TreemapNode> sortColumn;
  final List<ColumnData<TreemapNode>> columns;

  final AppSizeController controller;

  @override
  Widget build(BuildContext context) {
    return TreeTable<TreemapNode>(
      keyFactory: (node) => PageStorageKey<String>(node.name),
      dataRoots:
          controller.isDeferredApp.value ? rootNode.children : [rootNode],
      dataKey: 'app-size-analysis',
      columns: columns,
      treeColumn: treeColumn,
      defaultSortColumn: sortColumn,
      defaultSortDirection: SortDirection.descending,
      selectionNotifier: controller.analysisRoot,
      autoExpandRoots: true,
    );
  }
}

class _NameColumn extends TreeColumnData<TreemapNode> {
  _NameColumn({required this.currentRootLevel}) : super('Library or Class');

  final int currentRootLevel;

  @override
  String getValue(TreemapNode dataObject) => dataObject.name;

  @override
  String? getCaption(TreemapNode dataObject) => dataObject.caption;

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(TreemapNode dataObject) => dataObject.displayText();

  @override
  double getNodeIndentPx(TreemapNode dataObject) {
    final relativeLevel = dataObject.level - currentRootLevel;
    return relativeLevel * TreeColumnData.treeToggleWidth;
  }
}

class _SizeColumn extends ColumnData<TreemapNode> {
  _SizeColumn()
      : super(
          'Size',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(100.0),
        );

  @override
  Comparable getValue(TreemapNode dataObject) => dataObject.byteSize;

  @override
  String getDisplayValue(TreemapNode dataObject) {
    return prettyPrintBytes(dataObject.byteSize, includeUnit: true)!;
  }

  @override
  bool get supportsSorting => true;

  @override
  int compare(TreemapNode a, TreemapNode b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }
}

class _SizePercentageColumn extends ColumnData<TreemapNode> {
  _SizePercentageColumn({required this.totalSize})
      : super(
          '% of Total Size',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(100.0),
        );

  final int totalSize;

  @override
  double getValue(TreemapNode dataObject) =>
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
}

class AppSizeDiffTable extends StatelessWidget {
  factory AppSizeDiffTable({required TreemapNode rootNode}) {
    final treeColumn = _NameColumn(currentRootLevel: rootNode.level);
    final diffColumn = _DiffColumn();
    final columns = List<ColumnData<TreemapNode>>.unmodifiable([
      treeColumn,
      diffColumn,
    ]);

    return AppSizeDiffTable._(
      rootNode,
      treeColumn,
      diffColumn,
      columns,
    );
  }

  const AppSizeDiffTable._(
    this.rootNode,
    this.treeColumn,
    this.sortColumn,
    this.columns,
  );

  final TreemapNode rootNode;

  final TreeColumnData<TreemapNode> treeColumn;
  final ColumnData<TreemapNode> sortColumn;
  final List<ColumnData<TreemapNode>> columns;

  // TODO(petedjlee): Ensure the sort column is descending with the absolute value of the size
  //                  if the table is only showing negative values.
  @override
  Widget build(BuildContext context) {
    return TreeTable<TreemapNode>(
      keyFactory: (node) => PageStorageKey<String>(node.name),
      dataRoots: [rootNode],
      dataKey: 'app-size-diff',
      columns: columns,
      treeColumn: treeColumn,
      defaultSortColumn: sortColumn,
      defaultSortDirection: SortDirection.descending,
      autoExpandRoots: true,
    );
  }
}

// TODO(peterdjlee): Add an opaque overlay / background to differentiate from
//                   other columns.
class _DiffColumn extends ColumnData<TreemapNode> {
  _DiffColumn()
      : super(
          'Change',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(100.0),
        );

  // Ensure sort by absolute size.
  @override
  int getValue(TreemapNode dataObject) => dataObject.unsignedByteSize;

// TODO(peterdjlee): Add up or down arrows indicating increase or decrease for display value.
  @override
  String getDisplayValue(TreemapNode dataObject) => dataObject.prettyByteSize();

  @override
  bool get supportsSorting => true;

  @override
  int compare(TreemapNode a, TreemapNode b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  Color getTextColor(TreemapNode dataObject) {
    return dataObject.byteSize < 0 ? tableDecreaseColor : tableIncreaseColor;
  }
}

// TODO(peterdjlee): Add diff percentage column where we calculate percentage by
//                   (new - old) / new for every diff.
