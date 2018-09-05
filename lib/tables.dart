// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:devtools/framework/framework.dart';

import 'ui/elements.dart';
import 'utils.dart';

// TODO(devoncarew): fixed position header

// TODO(devoncarew): virtualize

class Table<T> extends Object with SetStateMixin {
  final CoreElement element;
  bool isVirtual = false;
  double rowHeight;

  List<Column<T>> columns = <Column<T>>[];
  List<T> rows;

  Column<T> _sortColumn;
  SortOrder _sortDirection;

  CoreElement _table;
  CoreElement _thead;
  CoreElement _tbody;
  CoreElement _beforeRowsSpacer;
  CoreElement _afterRowsSpacer;

  Map<Column<T>, CoreElement> spanForColumn = <Column<T>, CoreElement>{};

  final StreamController<T> _selectController =
      new StreamController<T>.broadcast();

  Table() : element = div(a: 'flex', c: 'overflow-y table-border') {
    _table = new CoreElement('table')..clazz('full-width');
    element.add(_table);
  }

  Table.virtual({this.rowHeight = 29.0})
      : element = div(a: 'flex', c: 'overflow-y table-border table-virtual'),
        isVirtual = true {
    _table = new CoreElement('table')..clazz('full-width');
    element.add(_table);
    _beforeRowsSpacer = new CoreElement('tr');
    _afterRowsSpacer = new CoreElement('tr');

    element.onScroll.listen((_) => setState(_rebuildTable));
  }

  Stream<T> get onSelect => _selectController.stream;

  void addColumn(Column<T> column) {
    columns.add(column);
  }

  void setRows(List<T> rows) {
    this.rows = rows.toList();

    if (_thead == null) {
      _thead = new CoreElement('thead')
        ..add(tr()
          ..add(columns.map((Column<T> column) {
            final CoreElement s = span(
                text: column.title,
                c: 'interactable${column.supportsSorting ? ' sortable' : ''}');
            s.click(() => _columnClicked(column));
            spanForColumn[column] = s;
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

    _rebuildTable();
  }

  void _doSort() {
    final Column<T> column = _sortColumn;
    final bool numeric = column.numeric;
    final int direction = _sortDirection == SortOrder.ascending ? 1 : -1;

    // update the sort arrows
    for (Column<T> c in columns) {
      final CoreElement s = spanForColumn[c];
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
    _clearSelection();

    // Re-build the table.
    final List<Element> rowElements = <Element>[];

    int firstRenderedRowInc = 0;
    int lastRenderedRowExc = rows?.length ?? 0;

    // If we're a virtual table, calculate the rows to render based on scroll
    // position. We'll include a "screens worth" of rows above/below to reduce
    // blank rendering as we scroll.
    if (isVirtual) {
      int firstVisibleRow =
          ((element.scrollTop - _thead.offsetHeight) / rowHeight).floor();
      // Snap to an even number to avoid the alternating background swapping
      // as you scroll down.
      if (firstVisibleRow % 2 != 0) {
        firstVisibleRow--;
      }
      final int numVisibleRows = (element.offsetHeight / rowHeight).ceil();
      firstRenderedRowInc =
          (firstVisibleRow - numVisibleRows).clamp(0, rows?.length ?? 0);
      lastRenderedRowExc =
          (firstVisibleRow + numVisibleRows * 2).clamp(0, rows?.length ?? 0);
    }

    if (firstRenderedRowInc > 0) {
      // Add a spacer row to fill up the content off-screen
      final double height = firstRenderedRowInc * rowHeight;
      _beforeRowsSpacer.height = '${height}px';
      rowElements.add(_beforeRowsSpacer.element);
    }
    for (T row in rows.sublist(firstRenderedRowInc, lastRenderedRowExc)) {
      final CoreElement tableRow = tr();
      if (rowHeight != null) {
        tableRow.height = '${rowHeight}px';
        tableRow.clazz('overflow-y');
      }

      for (Column<T> column in columns) {
        String cssClass = column.cssClass;

        if (cssClass != null && column.numeric) {
          cssClass = '$cssClass right';
        } else if (column.numeric) {
          cssClass = 'right';
        }

        if (column.usesHtml) {
          tableRow.add(
            td(c: cssClass)..setInnerHtml(column.render(column.getValue(row))),
          );
        } else {
          tableRow.add(
            td(text: column.render(column.getValue(row)), c: cssClass),
          );
        }
      }

      tableRow.click(() {
        _select(tableRow, row);
      });

      rowElements.add(tableRow.element);
    }
    if (lastRenderedRowExc < rows.length) {
      // Add spacer row
      final double height = (rows.length - lastRenderedRowExc - 1) * rowHeight;
      _afterRowsSpacer.height = '${height}px';
      rowElements.add(_afterRowsSpacer.element);
    }

    _tbody.clear();
    _tbody.element.children.addAll(rowElements);
  }

  CoreElement _selectedElement;
  T _selectedObject;

  void _select(CoreElement elementRow, T object) {
    if (_selectedObject == object) {
      return;
    }

    if (_selectedElement != null) {
      _selectedElement.toggleClass('selected', false);
      _selectedElement = null;
    }

    _selectedElement = elementRow;
    _selectedObject = object;

    if (_selectedElement != null) {
      _selectedElement.toggleClass('selected', true);
    }

    _selectController.add(object);
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
    _rebuildTable();
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
