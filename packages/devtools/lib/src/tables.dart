// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';

import 'framework/framework.dart';
import 'ui/elements.dart';
import 'utils.dart';

class Table<T> extends Object with SetStateMixin {
  Table()
      : element = div(a: 'flex', c: 'overflow-y table-border'),
        _isVirtual = false {
    _init();
  }

  Table.virtual({this.rowHeight = 29.0})
      : element = div(a: 'flex', c: 'overflow-y table-border table-virtual'),
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

  void _init() {
    element.add(_table);

    // handle hey events
    _table.onKeyDown.listen((KeyboardEvent e) {
      int indexOffset;
      // TODO(dantup): PgUp/PgDown/Home/End?
      if (e.keyCode == KeyCode.UP) {
        indexOffset = -1;
      } else if (e.keyCode == KeyCode.DOWN) {
        indexOffset = 1;
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

  void dispose() {}

  Stream<T> get onSelect => _selectController.stream;

  Stream<Null> get onRowsChanged => _rowsChangedController.stream;

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
      _clearSelection();
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
                th(c: 'sticky-top ${column.numeric ? 'right' : 'left'}')
                  ..add(s);
            if (column.wide) {
              header.clazz('wide');
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
        setSortColumn(column);
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

    data.sort((T a, T b) {
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
        currentRowIndex: currentRowIndex);

    // Remove any additional rows that we had left that we didn't reuse above.
    if (currentRowIndex > 0 &&
        currentRowIndex < _tbody.element.children.length) {
      // removeRange doesn't work in dart:html (UnimplementedError) so we have
      // to remove them one at a time.
      while (_tbody.element.children.length >= currentRowIndex) {
        _tbody.element.children.removeLast();
      }
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

        // TODO(dantup): Should we make CoreElement expose ClassList instead of
        // having flat strings?
        tableCell.element.classes.clear();
        if (column.cssClass != null) {
          column.cssClass.split(' ').forEach(tableCell.clazz);
        }

        if (column.numeric) {
          tableCell.clazz('right');
        }

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

  /// Selects by index. Note: This is index of the row as it's rendered
  /// and not necessarily for rows[] since it may be being rendered in reverse.
  /// This way, +1 will always move down the visible table.
  /// scrollBehaviour is a string as defined for the HTML scrollTo() method
  /// https://developer.mozilla.org/en-US/docs/Web/API/Window/scrollTo (eg.
  /// `smooth`, `instance`, `auto`).
  @visibleForTesting
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
      'left': 0,
      'top': newScrollTop,
      'behavior': scrollBehavior,
    });
  }

  double _rowOffset(int rowIndex) {
    return (rowIndex * rowHeight) + _thead.offsetHeight;
  }

  void _clearSelection() => _select(null, null, null);

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
  Column(this.title, {this.wide = false});

  final String title;
  final bool wide;

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
    final String content = render(getValue(dataObject));
    if (usesHtml) {
      cell.setInnerHtml(content);
    } else {
      cell.text = content;
    }
  }
}

enum SortOrder {
  ascending,
  descending,
}
