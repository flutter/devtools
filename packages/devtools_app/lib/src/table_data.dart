// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'trees.dart';
import 'utils.dart';

class HoverCellData<T> {
  HoverCellData(this.data);

  final T data;
}

abstract class TableDataClient<T> {
  void rebuildTable();

  /// Override to update data after setting rows.
  void onSetRows();

  void setState(VoidCallback modifyState);

  /// The way the columns are sorted have changed.
  ///
  /// Update the UI to reflect the new state.
  void onColumnSortChanged(ColumnData<T> column, SortDirection sortDirection);

  /// Selects by index. Note: This is index of the row as it's rendered
  /// and not necessarily for rows[] since it may be being rendered in reverse.
  /// This way, +1 will always move down the visible table.
  /// scrollBehaviour is a string as defined for the HTML scrollTo() method
  /// https://developer.mozilla.org/en-US/docs/Web/API/Window/scrollTo (eg.
  /// `smooth`, `instance`, `auto`).
  void selectByIndex(
    int newIndex, {
    bool keepVisible = true,
    String scrollBehavior = 'smooth',
  });

  void scrollToIndex(int rowIndex, {String scrollBehavior = 'smooth'});

  void clearSelection();
}

class TableData<T> extends Object {
  void setState(VoidCallback modifyState) {
    client?.setState(modifyState);
  }

  TableDataClient<T> client;

  bool _hasPendingRebuild = false;

  List<ColumnData<T>> get columns => _columns;

  final List<ColumnData<T>> _columns = <ColumnData<T>>[];

  List<T> data = [];

  int get rowCount => data?.length ?? 0;

  ColumnData<T> _sortColumn;

  SortDirection _sortDirection;

  set sortColumn(ColumnData<T> column) {
    _sortColumn = column;
    _sortDirection =
        column.numeric ? SortDirection.descending : SortDirection.ascending;
  }

  @protected
  final StreamController<T> selectController = StreamController<T>.broadcast();

  final StreamController<HoverCellData<T>> selectElementController =
      StreamController<HoverCellData<T>>.broadcast();

  @mustCallSuper
  void dispose() {
    client = null;
  }

  Stream<T> get onSelect => selectController.stream;

  Stream<void> get onRowsChanged => _rowsChangedController.stream;
  final _rowsChangedController = StreamController<void>.broadcast();

  Stream<HoverCellData<T>> get onCellHover => selectElementController.stream;

  void addColumn(ColumnData<T> column) {
    _columns.add(column);
  }

  void setRows(List<T> data) {
    // If the selected object is no longer valid, clear the selection and
    // scroll to the top.
    if (!data.contains(_selectedObject)) {
      if (rowCount > 0) {
        client?.scrollToIndex(0, scrollBehavior: 'auto');
      }
      client?.clearSelection();
    }

    // Copy the list, so that changes to it don't affect us.
    this.data = data.toList();

    _rowsChangedController.add(null);

    client?.onSetRows();

    if (_sortColumn == null) {
      final ColumnData<T> column = _columns.firstWhere(
          (ColumnData<T> c) => c.supportsSorting,
          orElse: () => null);
      if (column != null) {
        sortColumn = column;
      }
    }

    if (_sortColumn != null) {
      _doSort();
    }

    scheduleRebuild();
  }

  void scrollTo(T row, {String scrollBehavior = 'smooth'}) {
    final index = data.indexOf(row);
    if (index == -1) {
      return;
    }
    if (_hasPendingRebuild) {
      // Wait for the content to be rendered before we scroll otherwise we may
      // not be able to scroll far enough.
      setState(() {
        // We assume the index is still valid. Alternately we search for the
        // index again. The one thing we should absolutely not do is call the
        // scrollTo helper method again as there is a significant risk scrollTo
        // would never be called if items are added to the table every frame.
        client?.scrollToIndex(index, scrollBehavior: scrollBehavior);
      });
      return;
    }
    client?.scrollToIndex(index, scrollBehavior: scrollBehavior);
  }

  void scheduleRebuild() {
    if (!_hasPendingRebuild) {
      // Set a flag to ensure we don't schedule rebuilds if there's already one
      // in the queue.
      _hasPendingRebuild = true;

      setState(() {
        _hasPendingRebuild = false;
        client?.rebuildTable();
      });
    }
  }

  void _doSort() {
    final ColumnData<T> column = _sortColumn;
    final int direction = _sortDirection == SortDirection.ascending ? 1 : -1;

    client?.onColumnSortChanged(column, _sortDirection);

    _sortData(column, direction);
  }

  void _sortData(ColumnData column, int direction) {
    data.sort((T a, T b) => _compareData(a, b, column, direction));
  }

  int _compareData(T a, T b, ColumnData column, int direction) {
    return column.compare(a, b) * direction;
  }

  T get selectedObject => _selectedObject;
  T _selectedObject;

  int get selectedObjectIndex => _selectedObjectIndex;
  int _selectedObjectIndex;

  void setSelection(T object, int index) {
    assert(index == null || data[index] == object);
    _selectedObjectIndex = index;
    if (selectedObject != object) {
      _selectedObject = object;
      selectController.add(object);
    }
  }

  bool get hasSelection => _selectedObject != null;

  void onColumnClicked(ColumnData<T> column) {
    if (!column.supportsSorting) {
      return;
    }

    if (_sortColumn == column) {
      _sortDirection = _sortDirection.reverse();
    } else {
      sortColumn = column;
    }

    _doSort();
    scheduleRebuild();
  }

  /// Override this method if the table should handle left key strokes.
  void handleLeftKey() {}

  /// Override this method if the table should handle right key strokes.
  void handleRightKey() {}
}

/// Data for a tree table where nodes in the tree can be expanded and
/// collapsed.
///
/// A TreeTableData must have exactly one column that is a [TreeColumnData].
class TreeTableData<T extends TreeNode<T>> extends TableData<T> {
  @override
  void addColumn(ColumnData<T> column) {
    // Avoid adding multiple TreeColumnData columns.
    assert(column is! TreeColumnData<T> ||
        _columns.where((c) => c is TreeColumnData).isEmpty);
    super.addColumn(column);
  }

  @override
  void handleLeftKey() {
    if (_selectedObject != null) {
      if (_selectedObject.isExpanded) {
        // Collapse node and preserve selection.
        collapseNode(_selectedObject);
      } else {
        // Select the node's parent.
        final parentIndex = data.indexOf(_selectedObject.parent);
        if (parentIndex != null && parentIndex != -1) {
          client?.selectByIndex(parentIndex);
        }
      }
    }
  }

  @override
  void handleRightKey() {
    if (_selectedObject != null) {
      if (_selectedObject.isExpanded) {
        // Select the node's first child.
        final firstChildIndex = data.indexOf(_selectedObject.children.first);
        client?.selectByIndex(firstChildIndex);
      } else if (_selectedObject.isExpandable) {
        // Expand node and preserve selection.
        expandNode(_selectedObject);
      } else {
        // The node is not expandable. Select the next node in range.
        final nextIndex = data.indexOf(_selectedObject) + 1;
        if (nextIndex != data.length) {
          client?.selectByIndex(nextIndex);
        }
      }
    }
  }

  @override
  void _sortData(ColumnData column, int direction) {
    final List<T> sortedData = [];

    void _addToSortedData(T dataObject) {
      sortedData.add(dataObject);
      if (dataObject.isExpanded) {
        dataObject.children
          ..sort((T a, T b) => _compareData(a, b, column, direction))
          ..forEach(_addToSortedData);
      }
    }

    data.where((dataObject) => dataObject.level == 0).toList()
      ..sort((T a, T b) => _compareData(a, b, column, direction))
      ..forEach(_addToSortedData);

    data = sortedData;
  }

  void collapseNode(T dataObject) {
    void cascadingRemove(T _dataObject) {
      if (!data.contains(_dataObject)) return;
      data.remove(_dataObject);
      (_dataObject.children).forEach(cascadingRemove);
    }

    assert(data.contains(dataObject));
    dataObject.children.forEach(cascadingRemove);
    dataObject.collapse();

    _selectedObject ??= dataObject;
    setRows(data);
  }

  void expandNode(T dataObject) {
    void expand(T node) {
      assert(data.contains(node));
      int insertIndex = data.indexOf(node) + 1;
      for (T child in node.children) {
        data.insert(insertIndex, child);
        if (child.isExpanded) {
          expand(child);
        }
        insertIndex++;
      }
      node.expand();
    }

    expand(dataObject);

    _selectedObject ??= dataObject;
    setRows(data);
  }

  void expandAll() {
    // Store visited nodes so that we do not expand the same root multiple
    // times.
    final visited = <T>{};
    for (T dataObject in data) {
      final root = dataObject.root;
      if (!visited.contains(root)) {
        root.expandCascading();
        visited.add(root);
      }
    }

    setRows(data);
  }

  void collapseAll() {
    // Store visited nodes so that we do not collapse the same root multiple
    // times.
    final visited = <T>{};
    for (T dataObject in data) {
      final root = dataObject.root;
      if (!visited.contains(root)) {
        root.collapseCascading();
        visited.add(root);
      }
    }

    setRows(data);
  }
}

// TODO(peterdjlee): Remove get from method names.
abstract class ColumnData<T> {
  ColumnData(
    this.title, {
    this.alignment = ColumnAlignment.left,
    this.fixedWidthPx,
  });

  ColumnData.wide(this.title, {this.alignment = ColumnAlignment.left})
      : fixedWidthPx = null;

  final String title;

  /// Width of the column expressed as a fixed number of pixels.
  final double fixedWidthPx;

  /// How much to indent the data object by.
  ///
  /// This should only be non-zero for [TreeColumnData].
  double getNodeIndentPx(T dataObject) => 0.0;

  final ColumnAlignment alignment;

  bool get numeric => false;

  bool get supportsSorting => numeric;

  int compare(T a, T b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  /// Get the cell's value from the given [dataObject].
  dynamic getValue(T dataObject);

  /// Get the cell's display value from the given [dataObject].
  String getDisplayValue(T dataObject) => getValue(dataObject).toString();

  /// Get the cell's tooltip value from the given [dataObject].
  String getTooltip(T dataObject) => getDisplayValue(dataObject);

  /// Get the cell's text color from the given [dataObject].
  Color getTextColor(T dataObject) => null;

  @override
  String toString() => title;
}

abstract class TreeColumnData<T extends TreeNode<T>> extends ColumnData<T> {
  TreeColumnData(String title) : super(title);

  static const treeToggleWidth = 14.0;

  final StreamController<T> nodeExpandedController =
      StreamController<T>.broadcast();

  Stream<T> get onNodeExpanded => nodeExpandedController.stream;

  final StreamController<T> nodeCollapsedController =
      StreamController<T>.broadcast();

  Stream<T> get onNodeCollapsed => nodeCollapsedController.stream;

  @override
  double getNodeIndentPx(T dataObject) {
    double indentWidth = dataObject.level * treeToggleWidth;
    if (!dataObject.isExpandable) {
      // If the object is not expandable, we need to increase the width of our
      // spacer to account for the missing tree toggle.
      indentWidth += TreeColumnData.treeToggleWidth;
    }
    return indentWidth;
  }
}

enum ColumnAlignment {
  left,
  right,
  center,
}
