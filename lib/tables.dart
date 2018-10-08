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

class Table<T> extends Object with SetStateMixin, OnAddedToDomMixin {
  Table()
      : element = div(a: 'flex', c: 'overflow-y table-border'),
        _isVirtual = false,
        isReversed = false {
    _init();
  }

  Table.virtual({this.rowHeight = 29.0, this.isReversed = false})
      : element = div(a: 'flex', c: 'overflow-y table-border table-virtual'),
        _isVirtual = true {
    _init();
    _spacerBeforeVisibleRows = new CoreElement('tr');
    _spacerAfterVisibleRows = new CoreElement('tr');

    element.onScroll.listen((_) => _scheduleRebuild());
  }

  @override
  final CoreElement element;
  final bool _isVirtual;

  // Whether to reverse the display of data. This is to allow appending data
  // to this.rows quickly (using .add()) while still supporting new data being
  // inserted at the top.
  final bool isReversed;
  double rowHeight;
  bool _hasPendingRebuild = false;

  List<Column<T>> columns = <Column<T>>[];
  List<T> data;

  int get rowCount => data?.length ?? 0;

  Column<T> _sortColumn;
  SortOrder _sortDirection;

  final CoreElement _table = new CoreElement('table')
    ..clazz('full-width')
    ..setAttribute('tabIndex', '0');
  CoreElement _thead;
  CoreElement _tbody;

  CoreElement _spacerBeforeVisibleRows;
  CoreElement _spacerAfterVisibleRows;
  final CoreElement _dummyRowToForceAlternatingColor = new CoreElement('tr')
    ..display = 'none';

  final Map<Column<T>, CoreElement> _spanForColumn = <Column<T>, CoreElement>{};
  final Map<Element, T> _dataForRow = <Element, T>{};
  final Map<int, CoreElement> _rowForIndex = <int, CoreElement>{};

  final StreamController<T> _selectController =
      new StreamController<T>.broadcast();

  void _init() {
    _monitorWindowResizes();
    _rebuildWhenAddedToDom();

    element.add(_table);
    _table.onKeyDown.listen((KeyboardEvent e) {
      int indexOffset;
      if (e.keyCode == KeyCode.UP) {
        indexOffset = -1;
      } else if (e.keyCode == KeyCode.DOWN) {
        indexOffset = 1;
        // TODO(dantup): PgUp/PgDown/Home/End?
      } else {
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

  StreamSubscription<Event> _windowResizeSubscription;
  void _monitorWindowResizes() {
    // Monitor Window resizes but don't rebuild if we're not in the DOM.
    _windowResizeSubscription = window.onResize.listen((_) {
      if (!isInDom) {
        return;
      }
      _scheduleRebuild();
    });
  }

  StreamSubscription<void> _addToDomSubscription;
  void _rebuildWhenAddedToDom() {
    // When we're added to the DOM, force a rebuild since we may have
    // resized the window while we were not in the DOM.
    _addToDomSubscription = onAddedToDom.listen((_) => _scheduleRebuild());
  }

  void dispose() {
    _windowResizeSubscription?.cancel();
    _windowResizeSubscription = null;
    _addToDomSubscription?.cancel();
    _addToDomSubscription = null;
  }

  Stream<T> get onSelect => _selectController.stream;

  void addColumn(Column<T> column) {
    columns.add(column);
  }

  void setRows(List<T> data) {
    // If the selected object is no longer valid, clear the selection.
    if (!data.contains(_selectedObject)) {
      _clearSelection();
    }

    this.data = data;

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
    // If we've never had any data set, we don't need to (and can't - since
    // all the elements aren't created) rebuild.
    if (data == null) {
      return;
    }
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
      while (_tbody.element.children.length >= currentRowIndex)
        _tbody.element.children.removeLast();
    }
    // Set the "after" spacer to the correct height to keep the scroll size
    // correct for the number of rows to come after.
    final double spacerAfterHeight =
        (data.length - lastRenderedRowExclusive) * rowHeight;
    _spacerAfterVisibleRows.height = '${spacerAfterHeight}px';
    _tbody.element.children.add(_spacerAfterVisibleRows.element);

    // Restore the scroll position the user had scrolled to since Chrome may
    // have modified it after we changed the height of the "before" spacer.
    element.scrollTop = originalScrollTop;
  }

  void _rebuildStaticTable() => _buildTableRows(
      firstRenderedRowInclusive: 0,
      lastRenderedRowExclusive: data?.length ?? 0);

  int _translateRowIndex(int index) =>
      !isReversed ? index : (data?.length ?? 0) - 1 - index;

  int _buildTableRows({
    @required int firstRenderedRowInclusive,
    @required int lastRenderedRowExclusive,
    int currentRowIndex = 0,
  }) {
    _tbody.element.children.remove(_dummyRowToForceAlternatingColor.element);

    // Enable the dummy row to fix alternating backgrounds when the first rendered
    // row (taking into account if we're reversing) index is an odd.
    final bool shouldOffsetRowColor =
        _translateRowIndex(firstRenderedRowInclusive) % 2 == 1;
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
      final T dataObject = data[_translateRowIndex(index)];
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
          tableCell.setInnerHtml(column.render(column.getValue(dataObject)));
        } else {
          tableCell.text = column.render(column.getValue(dataObject));
        }

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
  @visibleForTesting
  void selectByIndex(int newIndex) {
    final CoreElement row = _rowForIndex[newIndex];
    final T dataObject = data[_translateRowIndex(newIndex)];
    _select(row?.element, dataObject, newIndex);
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
