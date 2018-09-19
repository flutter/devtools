// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:devtools/framework/framework.dart';
import 'package:meta/meta.dart';

import 'ui/elements.dart';
import 'utils.dart';

// TODO(devoncarew): fixed position header

// TODO(devoncarew): virtualize

class Table<T> extends Object with SetStateMixin {
  final CoreElement element;
  final bool _isVirtual;
  bool _offsetRowColor = false;
  double rowHeight;
  bool _hasPendingRebuild = false;

  List<Column<T>> columns = <Column<T>>[];
  List<T> rows;

  Column<T> _sortColumn;
  SortOrder _sortDirection;

  CoreElement _table;
  CoreElement _thead;
  CoreElement _tbody;

  CoreElement _spacerBeforeVisibleRows;
  CoreElement _spacerAfterVisibleRows;
  final CoreElement _dummyRowToForceAlternatingColor = new CoreElement('tr')
    ..display = 'none';

  final Map<Column<T>, CoreElement> _spanForColumn = <Column<T>, CoreElement>{};
  final Map<Element, T> _dataForRow = <Element, T>{};

  final StreamController<T> _selectController =
      new StreamController<T>.broadcast();

  Table()
      : element = div(a: 'flex', c: 'overflow-y table-border'),
        _isVirtual = false {
    _table = new CoreElement('table')..clazz('full-width');
    element.add(_table);
  }

  Table.virtual({this.rowHeight = 29.0})
      : element = div(a: 'flex', c: 'overflow-y table-border table-virtual'),
        _isVirtual = true {
    _table = new CoreElement('table')..clazz('full-width');
    element.add(_table);
    _spacerBeforeVisibleRows = new CoreElement('tr');
    _spacerAfterVisibleRows = new CoreElement('tr');

    element.onScroll.listen((_) => _scheduleRebuild());
  }

  Stream<T> get onSelect => _selectController.stream;

  void addColumn(Column<T> column) {
    columns.add(column);
  }

  void setRows(List<T> rows, {bool anchorAlternatingRowsToBottom = false}) {
    // If the selected object is no longer valid, clear the selection.
    if (!rows.contains(_selectedObject)) {
      _clearSelection();
    }

    // For tables that insert rows at the top, we'd like to preserve the background
    // color for each (eg. when we insert one row, the previous-top row should
    // have the same background color even though it's gone from odd to even).
    // To achieve this, we have a boolean that dictates whether we insert a dummy row
    // at the top, and will reverse it when the number of rows being inserted into
    // the table is odd.
    final int differenceInRowCount =
        (rows?.length ?? 0) - (this.rows?.length ?? 0);
    if (anchorAlternatingRowsToBottom && differenceInRowCount % 2 == 1) {
      _offsetRowColor = !_offsetRowColor;
    }
    this.rows = rows;

    if (_thead == null) {
      _thead = new CoreElement('thead')
        ..add(tr()
          ..add(columns.map((Column<T> column) {
            final CoreElement s = span(
                text: column.title,
                c: 'interactable${column.supportsSorting ? ' sortable' : ''}');
            s.click(() => _columnClicked(column));
            _spanForColumn[column] = s;
            final CoreElement header = th(c: column.numeric ? 'right' : 'left')
              ..add(s);
            if (column.wide) {
              header.clazz('wide');
            }
            return header;
          })));

      _table.add(_thead);
    }

    if (_tbody == null) {
      _tbody = new CoreElement('tbody', classes: 'selectable');
      _table.add(_tbody);
    }

    if (_sortColumn == null) {
      final Column<T> column = columns
          .firstWhere((Column<T> c) => c.supportsSorting, orElse: () => null);
      if (column != null) {
        setSortColumn(column);
      }
    }

    if (_sortColumn != null) {
      _doSort();
    }

    _scheduleRebuild();
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
    final bool numeric = column.numeric;
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

    rows.sort((T a, T b) {
      if (numeric) {
        final num one = column.getValue(a);
        final num two = column.getValue(b);
        if (one == two) {
          return 0;
        }
        if (_sortDirection == SortOrder.ascending) {
          return one > two ? 1 : -1;
        } else {
          return one > two ? -1 : 1;
        }
      } else {
        final String one = column.render(column.getValue(a));
        final String two = column.render(column.getValue(b));
        return one.compareTo(two) * direction;
      }
    });
  }

  void _rebuildTable() {
    if (_isVirtual)
      _rebuildVirtualTable();
    else
      _rebuildStaticTable();
  }

  void _rebuildVirtualTable() {
    // When we modify the height of the spacer above the viewport, Chrome automatically
    // adjusts the scrollTop to compensate because it's trying to keep the same content
    // visible to the user. However, since we're overwriting the rows contents (shifting
    // the data in the rows) we want to retain the original scroll position so must stash
    // it and reset it later.
    final int originalScrollTop = element.scrollTop;

    int firstRenderedRowInclusive = 0;
    int lastRenderedRowExclusive = rows?.length ?? 0;

    // Keep track of the table row we're inserting so that we can re-use rows
    // if they already exist in the DOM.
    int currentRowIndex = 0;

    // Calculate the subset of rows to render based on scroll position.
    final int totalRows = rows?.length ?? 0;
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
        currentRowIndex: currentRowIndex);

    // Remove any additional rows that we had left that we didn't reuse above.
    if (currentRowIndex > 0 &&
        currentRowIndex < _tbody.element.children.length) {
      // removeRange doesn't work in dart:html (UnimplementedError) so we have
      // to remove them one at a time.
      while (_tbody.element.children.length >= currentRowIndex)
        _tbody.element.children.removeLast();
    }
    // Set the "after" spacer to the correct height to keep the scroll size
    // correct for the number or rows to come after.
    final double spacerAfterHeight =
        (rows.length - lastRenderedRowExclusive) * rowHeight;
    _spacerAfterVisibleRows.height = '${spacerAfterHeight}px';
    _tbody.element.children.add(_spacerAfterVisibleRows.element);

    // Restore the scroll position the user had scrolled to since Chrome may
    // have modified it after we changed the height of the "before" spacer.
    element.scrollTop = originalScrollTop;
  }

  void _rebuildStaticTable() => _buildTableRows(
      firstRenderedRowInclusive: 0,
      lastRenderedRowExclusive: rows?.length ?? 0);

  int _buildTableRows({
    @required int firstRenderedRowInclusive,
    @required int lastRenderedRowExclusive,
    int currentRowIndex = 0,
  }) {
    _tbody.element.children.remove(_dummyRowToForceAlternatingColor.element);
    bool shouldOffsetRowColor = _offsetRowColor;
    // If we're skipping an odd number or rows, we need to invert whether to include
    // the row color compensator.
    if (firstRenderedRowInclusive % 2 == 1) {
      shouldOffsetRowColor = !shouldOffsetRowColor;
    }
    if (shouldOffsetRowColor) {
      _tbody.element.children
          .insert(0, _dummyRowToForceAlternatingColor.element);
      currentRowIndex++;
    }

    for (T row
        in rows.sublist(firstRenderedRowInclusive, lastRenderedRowExclusive)) {
      final bool isReusableRow =
          currentRowIndex < _tbody.element.children.length;
      // Reuse a row if one already exists in the table.
      final CoreElement tableRow = isReusableRow
          ? new CoreElement.from(_tbody.element.children[currentRowIndex])
          : tr();

      currentRowIndex++;

      // Keep the data for each row in a map so we can look it up when the
      // user clicks the row to select it. This lets us reuse a single
      // click handler attached when we created the row instead of rebinding
      // it when rows are reused as we scroll.
      _dataForRow[tableRow.element] = row;
      void selectRow(Element row) {
        _select(row, _dataForRow[row]);
      }

      if (!isReusableRow) {
        tableRow.click(() => selectRow(tableRow.element));
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
            ? new CoreElement.from(
                tableRow.element.children[currentColumnIndex])
            : td();

        currentColumnIndex++;

        // TODO(dantup): Should we make CoreElement expose ClassList instead
        // of having flat strings?
        tableCell.element.classes.clear();
        if (column.cssClass != null) {
          column.cssClass.split(' ').forEach(tableCell.clazz);
        }

        if (column.numeric) {
          tableCell.clazz('right');
        }

        if (column.usesHtml) {
          tableCell..setInnerHtml(column.render(column.getValue(row)));
        } else {
          tableCell.text = column.render(column.getValue(row));
        }

        if (!isReusableColumn) {
          tableRow.add(tableCell);
        }
      }

      // If this row represents our selected object, highlight it.
      if (row == _selectedObject) {
        _select(tableRow.element, _selectedObject);
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

  void _select(Element row, T object) {
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
  }

  void _clearSelection() => _select(null, null);

  void setSortColumn(Column<T> column) {
    _sortColumn = column;
    _sortDirection =
        column.numeric ? SortOrder.descending : SortOrder.ascending;
  }

  void _columnClicked(Column<T> column) {
    if (!column.supportsSorting) {
      return;
    }

    if (_sortColumn == column) {
      _sortDirection = _sortDirection == SortOrder.ascending
          ? SortOrder.descending
          : SortOrder.ascending;
    } else {
      setSortColumn(column);
    }

    _doSort();
    _scheduleRebuild();
  }
}

abstract class Column<T> {
  final String title;
  final bool wide;

  Column(this.title, {this.wide = false});

  String get cssClass => null;

  bool get numeric => false;

  bool get supportsSorting => numeric;

  bool get usesHtml => false;

  /// Get the cell's value from the given [item].
  dynamic getValue(T item);

  /// Given a value from [getValue], render it to a String.
  String render(dynamic value) {
    if (numeric) {
      return fastIntl(value);
    }
    return value.toString();
  }

  static String fastIntl(int value) {
    if (value is int && value < 1000) {
      return value.toString();
    } else {
      return nf.format(value);
    }
  }

  @override
  String toString() => title;
}

enum SortOrder {
  ascending,
  descending,
}
