// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';

import 'framework/framework.dart';
import 'trees.dart';
import 'ui/custom.dart';
import 'ui/elements.dart';
import 'utils.dart';

class HoverCellData<T> {
  HoverCellData(this.cell, this.data);

  final CoreElement cell;
  final T data;
}

class Table<T> extends Object with SetStateMixin {
  Table()
      : element = div(a: 'flex', c: 'overflow-y table-border'),
        _isVirtual = false {
    _init();
  }

  Table.virtual({this.rowHeight = 29.0, bool overflowAuto = false})
      : element = div(
            a: 'flex',
            c: '${overflowAuto ? 'overflow-auto' : 'overflow-y'} '
                'table-border table-virtual'),
        _isVirtual = true {
    _init();

    _spacerBeforeVisibleRows = CoreElement('tr');
    _spacerAfterVisibleRows = CoreElement('tr');

    element.onScroll.listen((_) => _scheduleRebuild());
  }

  final CoreElement element;
  final bool _isVirtual;

  double rowHeight;
  bool _hasPendingRebuild = false;

  List<Column<T>> columns = <Column<T>>[];
  List<T> data;

  int get rowCount => data?.length ?? 0;

  Column<T> _sortColumn;

  SortOrder _sortDirection;

  set sortColumn(Column<T> column) {
    _sortColumn = column;
    _sortDirection =
        column.numeric ? SortOrder.descending : SortOrder.ascending;
  }

  final CoreElement _table = CoreElement('table')
    ..clazz('full-width')
    ..setAttribute('tabIndex', '0');
  CoreElement _thead;
  CoreElement _tbody;

  CoreElement _spacerBeforeVisibleRows;
  CoreElement _spacerAfterVisibleRows;
  final CoreElement _dummyRowToForceAlternatingColor = CoreElement('tr')
    ..display = 'none';

  final Map<Column<T>, CoreElement> _spanForColumn = <Column<T>, CoreElement>{};
  final Map<Element, T> _dataForRow = <Element, T>{};
  final Map<int, CoreElement> _rowForIndex = <int, CoreElement>{};

  final StreamController<T> _selectController = StreamController<T>.broadcast();
  final StreamController<Null> _rowsChangedController =
      StreamController.broadcast();

  final StreamController<HoverCellData<T>> _selectElementController =
      StreamController<HoverCellData<T>>.broadcast();

  void _init() {
    element.add(_table);

    // Handle key events.
    _table.onKeyDown.listen((KeyboardEvent e) {
      int indexOffset;
      // TODO(dantup): PgUp/PgDown/Home/End?
      switch (e.keyCode) {
        case KeyCode.UP:
          indexOffset = -1;
          break;
        case KeyCode.DOWN:
          indexOffset = 1;
          break;
        case KeyCode.LEFT:
          _handleLeftKey();
          break;
        case KeyCode.RIGHT:
          _handleRightKey();
          break;
        default:
          break;
      }

      if (indexOffset == null) {
        return;
      }

      e.preventDefault();

      // Get the index of the currently selected row.
      final int currentIndex = _selectedObjectIndex;
      // Offset it, or select index 0 if there was no prior selection.
      int newIndex = currentIndex == null ? 0 : (currentIndex + indexOffset);
      // Clamp to the first/last row.
      final int maxRowIndex = (data?.length ?? 1) - 1;
      newIndex = newIndex.clamp(0, maxRowIndex);

      selectByIndex(newIndex);
    });
  }

  // Override this method if the table should handle left key strokes.
  void _handleLeftKey() {}

  // Override this method if the table should handle right key strokes.
  void _handleRightKey() {}

  void dispose() {}

  Stream<T> get onSelect => _selectController.stream;

  Stream<Null> get onRowsChanged => _rowsChangedController.stream;

  Stream<HoverCellData<T>> get onCellHover => _selectElementController.stream;

  void addColumn(Column<T> column) {
    columns.add(column);
  }

  void setRows(List<T> data) {
    // If the selected object is no longer valid, clear the selection and
    // scroll to the top.
    if (!data.contains(_selectedObject)) {
      if (rowCount > 0) {
        _scrollToIndex(0, scrollBehavior: 'auto');
      }
      clearSelection();
    }

    // Copy the list, so that changes to it don't affect us.
    this.data = data.toList();

    _rowsChangedController.add(null);

    if (_thead == null) {
      _thead = CoreElement('thead')
        ..add(tr()
          ..add(columns.map((Column<T> column) {
            final CoreElement s = span(
                text: column.title,
                c: 'interactable${column.supportsSorting ? ' sortable' : ''}');
            s.click(() => _columnClicked(column));
            _spanForColumn[column] = s;
            final CoreElement header =
                th(c: 'sticky-top ${column.alignmentCss}')..add(s);
            if (column.fixedWidthPx != null) {
              header.element.style.width = '${column.fixedWidthPx}px';
            } else if (column.percentWidth != null) {
              header.element.style.width = '${column.percentWidth}%';
            }
            return header;
          })));

      _table.add(_thead);
    }

    if (_tbody == null) {
      _tbody = CoreElement('tbody', classes: 'selectable');
      _table.add(_tbody);
    }

    if (_sortColumn == null) {
      final Column<T> column = columns
          .firstWhere((Column<T> c) => c.supportsSorting, orElse: () => null);
      if (column != null) {
        sortColumn = column;
      }
    }

    if (_sortColumn != null) {
      _doSort();
    }

    _scheduleRebuild();
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
        _scrollToIndex(index, scrollBehavior: scrollBehavior);
      });
      return;
    }
    _scrollToIndex(index, scrollBehavior: scrollBehavior);
  }

  void _scheduleRebuild() {
    if (!_hasPendingRebuild) {
      // Set a flag to ensure we don't schedule rebuilds if there's already one
      // in the queue.
      _hasPendingRebuild = true;

      setState(() {
        _hasPendingRebuild = false;
        _rebuildTable();
      });
    }
  }

  void _doSort() {
    final Column<T> column = _sortColumn;
    final int direction = _sortDirection == SortOrder.ascending ? 1 : -1;

    // update the sort arrows
    for (Column<T> c in columns) {
      final CoreElement s = _spanForColumn[c];
      if (c == _sortColumn) {
        s.toggleClass('up', _sortDirection == SortOrder.ascending);
        s.toggleClass('down', _sortDirection != SortOrder.ascending);
      } else {
        s.toggleClass('up', false);
        s.toggleClass('down', false);
      }
    }

    _sortData(column, direction);
  }

  void _sortData(Column column, int direction) {
    data.sort((T a, T b) => _compareData(a, b, column, direction));
  }

  int _compareData(T a, T b, Column column, int direction) {
    final Comparable valueA = column.render(column.getValue(a));
    final Comparable valueB = column.render(column.getValue(b));
    return valueA.compareTo(valueB) * direction;
  }

  void _rebuildTable() {
    // If we've never had any data set, we don't need to (and can't - since all
    // the elements aren't created) rebuild.
    if (data == null) {
      return;
    }

    if (_isVirtual) {
      _rebuildVirtualTable();
    } else {
      _rebuildStaticTable();
    }
  }

  void _rebuildVirtualTable() {
    // TODO(devoncarew): We should make this more efficient. We currently
    // rebuild the entire table on each scroll. Often scrolls are small, and the
    // set of rows currently in the table are already correct. We also don't
    // need to build rows that are already in the table, just add and remove the
    // deltas.

    int firstRenderedRowInclusive = 0;
    int lastRenderedRowExclusive = data?.length ?? 0;

    // Keep track of the table row we're inserting so that we can re-use rows
    // if they already exist in the DOM.
    int currentRowIndex = 0;

    // Calculate the subset of rows to render based on scroll position.
    final int totalRows = data?.length ?? 0;
    final int firstVisibleRow =
        ((element.scrollTop - _thead.offsetHeight) / rowHeight).floor();
    final int numVisibleRows = (element.offsetHeight / rowHeight).ceil() + 1;
    final int highestPossibleFirstRenderedRow =
        (totalRows - (numVisibleRows + 1)).clamp(0, totalRows);
    firstRenderedRowInclusive =
        firstVisibleRow.clamp(0, highestPossibleFirstRenderedRow);
    // Calculate the last rendered row. +2 is for:
    //   1) because it's exclusive so needs to be one higher
    //   2) because we need to render the extra partially-visible row
    lastRenderedRowExclusive =
        (firstRenderedRowInclusive + numVisibleRows + 2).clamp(0, totalRows);

    // Add a spacer row to fill up the content off-screen.
    final double spacerBeforeHeight = firstRenderedRowInclusive * rowHeight;
    _spacerBeforeVisibleRows.height = '${spacerBeforeHeight}px';
    _spacerBeforeVisibleRows.display = spacerBeforeHeight == 0 ? 'none' : null;

    // If the spacer row isn't already at the start of the list, add it.
    if (_tbody.element.children.isEmpty ||
        _tbody.element.children.first != _spacerBeforeVisibleRows.element) {
      _tbody.element.children.insert(0, _spacerBeforeVisibleRows.element);
    }
    currentRowIndex++;

    // Remove the last row if it's the spacer - we'll re-add it later if required
    // but it simplifies things if we can just append any new rows we need to create
    // to the end.
    if (_tbody.element.children.isNotEmpty &&
        _tbody.element.children.last == _spacerAfterVisibleRows.element) {
      _tbody.element.children.removeLast();
    }

    currentRowIndex = _buildTableRows(
      firstRenderedRowInclusive: firstRenderedRowInclusive,
      lastRenderedRowExclusive: lastRenderedRowExclusive,
      currentRowIndex: currentRowIndex,
    );

    // Remove any additional rows that we had left that we didn't reuse above.
    if (currentRowIndex > 0 &&
        currentRowIndex < _tbody.element.children.length) {
      _tbody.element.children.removeWhere((e) {
        final rowElementsInUse =
            _rowForIndex.values.map((CoreElement el) => el.element).toList();
        return !rowElementsInUse.contains(e) &&
            e != _spacerBeforeVisibleRows.element;
      });
    }

    // Set the "after" spacer to the correct height to keep the scroll size
    // correct for the number of rows to come after.
    final double spacerAfterHeight =
        (data.length - lastRenderedRowExclusive) * rowHeight;
    _spacerAfterVisibleRows.height = '${spacerAfterHeight}px';
    _tbody.element.children.add(_spacerAfterVisibleRows.element);
  }

  void _rebuildStaticTable() {
    _buildTableRows(
        firstRenderedRowInclusive: 0,
        lastRenderedRowExclusive: data?.length ?? 0);
  }

  int _buildTableRows({
    @required int firstRenderedRowInclusive,
    @required int lastRenderedRowExclusive,
    int currentRowIndex = 0,
  }) {
    _tbody.element.children.remove(_dummyRowToForceAlternatingColor.element);

    // Enable the dummy row to fix alternating backgrounds when the first rendered
    // row (taking into account if we're reversing) index is an odd.
    final bool shouldOffsetRowColor = firstRenderedRowInclusive % 2 == 1;
    if (shouldOffsetRowColor) {
      _tbody.element.children
          .insert(0, _dummyRowToForceAlternatingColor.element);
      currentRowIndex++;
    }

    // Our current indexes might not all be reused, so clear out the old data
    // so we don't have invalid pointers left here.
    _rowForIndex.clear();

    for (int index = firstRenderedRowInclusive;
        index < lastRenderedRowExclusive;
        index++) {
      final T dataObject = data[index];
      final bool isReusableRow =
          currentRowIndex < _tbody.element.children.length;
      // Reuse a row if one already exists in the table.
      final CoreElement tableRow = isReusableRow
          ? CoreElement.from(_tbody.element.children[currentRowIndex])
          : tr();

      currentRowIndex++;

      // Keep the data for each row in a map so we can look it up when the
      // user clicks the row to select it. This lets us reuse a single
      // click handler attached when we created the row instead of rebinding
      // it when rows are reused as we scroll.
      _dataForRow[tableRow.element] = dataObject;
      void selectRow(Element row, int index) {
        _select(row, _dataForRow[row], index);
      }

      void hoverCell(CoreElement row, CoreElement cell, int rowIndex) {
        _selectCoreElement(cell, _dataForRow[row.element], rowIndex);
      }

      // We also keep a lookup to get the row for the index of index to allow
      // easy changing of the selected row with keyboard (which needs to offset
      // the selected index).
      _rowForIndex[index] = tableRow;

      if (!isReusableRow) {
        tableRow.click(() => selectRow(tableRow.element, index));
      }

      if (rowHeight != null) {
        tableRow.height = '${rowHeight}px';
        tableRow.clazz('overflow-y');
      }

      int currentColumnIndex = 0;
      for (Column<T> column in columns) {
        final bool isReusableColumn =
            currentColumnIndex < tableRow.element.children.length;
        // Reuse or create a cell.
        final CoreElement tableCell = isReusableColumn
            ? CoreElement.from(tableRow.element.children[currentColumnIndex])
            : td();

        currentColumnIndex++;

        if (column.hover) {
          if (tableCell.over != hoverCell) {
            tableCell.over(() => hoverCell(tableRow, tableCell, index));
          }
          if (tableCell.leave != hoverCell) {
            tableCell.leave(() => hoverCell(tableRow, null, index));
          }
        }

        // TODO(dantup): Should we make CoreElement expose ClassList instead of
        // having flat strings?
        tableCell.element.classes.clear();
        if (column.cssClass != null) {
          column.cssClass.split(' ').forEach(tableCell.clazz);
        }

        tableCell.clazz(column.alignmentCss);

        column.renderToElement(tableCell, dataObject);

        if (!isReusableColumn) {
          tableRow.add(tableCell);
        }
      }

      // If this row represents our selected object, highlight it.
      if (dataObject == _selectedObject) {
        _select(tableRow.element, _selectedObject, index);
      } else {
        // Otherwise, ensure it's not marked as selected (the previous data
        // shown in this row may have been selected).
        tableRow.element.classes.remove('selected');
      }

      if (!isReusableRow) {
        _tbody.element.children.add(tableRow.element);
      }
    }
    return currentRowIndex;
  }

  T _selectedObject;

  int _selectedObjectIndex;

  bool get hasSelection => _selectedObject != null;

  void _select(Element row, T object, int index) {
    if (_tbody != null) {
      for (Element row in _tbody.element.querySelectorAll('.selected')) {
        row.classes.remove('selected');
      }
    }

    if (row != null) {
      row.classes.add('selected');
    }

    if (_selectedObject != object) {
      _selectController.add(object);
    }

    _selectedObject = object;
    _selectedObjectIndex = index;
  }

  void _selectCoreElement(CoreElement coreElement, T object, int index) {
    _selectElementController.add(HoverCellData<T>(coreElement, object));
  }

  /// Selects by index. Note: This is index of the row as it's rendered
  /// and not necessarily for rows[] since it may be being rendered in reverse.
  /// This way, +1 will always move down the visible table.
  /// scrollBehaviour is a string as defined for the HTML scrollTo() method
  /// https://developer.mozilla.org/en-US/docs/Web/API/Window/scrollTo (eg.
  /// `smooth`, `instance`, `auto`).
  void selectByIndex(int newIndex,
      {bool keepVisible = true, String scrollBehavior = 'smooth'}) {
    final CoreElement row = _rowForIndex[newIndex];
    final T dataObject = data[newIndex];
    _select(row?.element, dataObject, newIndex);

    if (keepVisible) {
      _scrollToIndex(newIndex, scrollBehavior: scrollBehavior);
    }
  }

  void _scrollToIndex(int rowIndex, {String scrollBehavior = 'smooth'}) {
    final double rowOffsetPixels = _rowOffset(rowIndex);
    final int visibleStartOffsetPixels = element.scrollTop;
    final int visibleEndOffsetPixels = element.scrollTop + element.offsetHeight;
    // If the row Offset is at least 1 row within the visible area, we don't need
    // to scroll. We subtract an extra rowHeight from the end to allow for the height
    // of the row itself.
    final double allowedViewportStart = visibleStartOffsetPixels + rowHeight;
    final double allowedViewportEnd = visibleEndOffsetPixels - rowHeight * 2;

    if (rowOffsetPixels >= allowedViewportStart &&
        rowOffsetPixels <= allowedViewportEnd) {
      return;
    }

    final double halfTableHeight = element.offsetHeight / 2;
    final int newScrollTop = (rowOffsetPixels - halfTableHeight)
        .round()
        .clamp(0, element.scrollHeight);

    element.element.scrollTo(<String, dynamic>{
      'left': element.element.scrollLeft,
      'top': newScrollTop,
      'behavior': scrollBehavior,
    });
  }

  double _rowOffset(int rowIndex) {
    return (rowIndex * rowHeight) + _thead.offsetHeight;
  }

  void clearSelection() => _select(null, null, null);

  void _columnClicked(Column<T> column) {
    if (!column.supportsSorting) {
      return;
    }

    if (_sortColumn == column) {
      _sortDirection = _sortDirection == SortOrder.ascending
          ? SortOrder.descending
          : SortOrder.ascending;
    } else {
      sortColumn = column;
    }

    _doSort();
    _scheduleRebuild();
  }
}

class TreeTable<T extends TreeNode<T>> extends Table<T> {
  TreeTable.virtual({double rowHeight = 29.0})
      : super.virtual(rowHeight: rowHeight, overflowAuto: true);

  @override
  void _handleLeftKey() {
    if (_selectedObject != null) {
      if (_selectedObject.isExpanded) {
        // Collapse node and preserve selection.
        collapseNode(_selectedObject);
      } else {
        // Select the node's parent.
        final parentIndex = data.indexOf(_selectedObject.parent);
        if (parentIndex != null) {
          selectByIndex(parentIndex);
        }
      }
    }
  }

  @override
  void _handleRightKey() {
    if (_selectedObject != null) {
      if (_selectedObject.isExpanded) {
        // Select the node's first child.
        final firstChildIndex = data.indexOf(_selectedObject.children.first);
        selectByIndex(firstChildIndex);
      } else if (_selectedObject.isExpandable) {
        // Expand node and preserve selection.
        expandNode(_selectedObject);
      }
    }
  }

  @override
  void _sortData(Column column, int direction) {
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
    dataObject.isExpanded = false;
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
      node.isExpanded = true;
    }

    expand(dataObject);
    setRows(data);
  }
}

abstract class Column<T> {
  Column(
    this.title, {
    ColumnAlignment alignment = ColumnAlignment.left,
    this.fixedWidthPx,
    this.percentWidth,
    this.usesHtml = false,
    this.hover = false,
    this.cssClass,
  }) : _alignment = alignment {
    if (percentWidth != null) {
      percentWidth.clamp(0, 100);
    }
  }

  Column.wide(this.title,
      {ColumnAlignment alignment = ColumnAlignment.left,
      this.usesHtml = false,
      this.hover = false,
      this.cssClass})
      : _alignment = alignment,
        percentWidth = defaultWideColumnPercentWidth;

  static const defaultWideColumnPercentWidth = 100;

  final String title;

  /// Width of the column expressed as a fixed number of pixels.
  ///
  /// If both [fixedWidthPx] and [percentWidth] are specified, [fixedWidthPx]
  /// will be used.
  int fixedWidthPx;

  /// Width of the column expressed as a percent value between 0 and 100.
  int percentWidth;

  String get alignmentCss => _getAlignmentCss(_alignment);

  final ColumnAlignment _alignment;

  final bool usesHtml;
  final String cssClass;
  final bool hover;

  bool get numeric => false;

  bool get supportsSorting => numeric;

  /// Get the cell's value from the given [dataObject].
  dynamic getValue(T dataObject);

  /// Get the cell's display value from the given [dataObject].
  dynamic getDisplayValue(T dataObject) => getValue(dataObject);

  /// Get the cell's tooltip value from the given [dataObject].
  String getTooltip(T dataObject) => '';

  /// Given a value from [getValue], render it to a String.
  String render(dynamic value) {
    if (value is num) {
      return fastIntl(value);
    }
    return value.toString();
  }

  static String fastIntl(num value) {
    if (value is int && value < 1000) {
      return value.toString();
    } else {
      return nf.format(value);
    }
  }

  @override
  String toString() => title;

  void renderToElement(CoreElement cell, T dataObject) {
    final String content = render(getDisplayValue(dataObject));
    if (usesHtml) {
      cell.setInnerHtml(content);
    } else {
      cell.text = content;
    }
    cell.tooltip = getTooltip(dataObject);
  }

  String _getAlignmentCss(ColumnAlignment alignment) {
    switch (alignment) {
      case ColumnAlignment.left:
        return 'left';
      case ColumnAlignment.right:
        return 'right';
      case ColumnAlignment.center:
        return 'center';
      default:
        throw Exception('Invalid column alignment: $alignment');
    }
  }
}

abstract class TreeColumn<T extends TreeNode<T>> extends Column<T> {
  TreeColumn(
    title, {
    int fixedWidthPx,
    int percentWidth,
  }) : super(title, fixedWidthPx: fixedWidthPx, percentWidth: percentWidth);

  static const treeToggleWidth = 14;

  final StreamController<T> _nodeExpandedController =
      StreamController<T>.broadcast();

  Stream<T> get onNodeExpanded => _nodeExpandedController.stream;

  final StreamController<T> _nodeCollapsedController =
      StreamController<T>.broadcast();

  Stream<T> get onNodeCollapsed => _nodeCollapsedController.stream;

  int _getNodeIndentPx(T dataObject) {
    int indentWidth = dataObject.level * treeToggleWidth;
    if (!dataObject.isExpandable) {
      // If the object is not expandable, we need to increase the width of our
      // spacer to account for the missing tree toggle.
      indentWidth += TreeColumn.treeToggleWidth;
    }
    return indentWidth;
  }

  @override
  void renderToElement(CoreElement cell, T dataObject) {
    final container = div()
      ..layoutHorizontal()
      ..flex()
      // Add spacer to beginning of element that reflects tree structure.
      ..add(
          div()..element.style.minWidth = '${_getNodeIndentPx(dataObject)}px');

    if (dataObject.isExpandable) {
      final TreeToggle treeToggle = TreeToggle(forceOpen: dataObject.isExpanded)
        ..onOpen.listen((isOpen) {
          if (isOpen) {
            _nodeExpandedController.add(dataObject);
          } else {
            _nodeCollapsedController.add(dataObject);
          }
        });
      container.add(treeToggle);
    }

    container.add(div(text: render(getDisplayValue(dataObject))));

    cell
      ..clear()
      ..add(container)
      ..tooltip = getTooltip(dataObject);
  }
}

enum ColumnAlignment {
  left,
  right,
  center,
}

enum SortOrder {
  ascending,
  descending,
}
