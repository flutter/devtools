// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'ui/elements.dart';
import 'utils.dart';

// TODO: fixed position header

// TODO: virtualize

class Table<T> {
  final CoreElement element;

  List<Column<T>> columns = [];
  List<T> rows;

  Column<T> _sortColumn;
  SortOrder _sortDirection;

  CoreElement _table;
  CoreElement _thead;
  CoreElement _tbody;

  Map<Column, CoreElement> spanForColumn = {};

  final StreamController<T> _selectController =
      new StreamController.broadcast();

  Table() : element = div(a: 'flex', c: 'overflow-y table-border') {
    _table = new CoreElement('table')..clazz('full-width');
    element.add(_table);
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
          ..add(columns.map((Column column) {
            CoreElement s = span(
                text: column.title,
                c: 'interactable${column.supportsSorting ? ' sortable' : ''}');
            s.click(() => _columnClicked(column));
            spanForColumn[column] = s;
            CoreElement header = th(c: column.numeric ? 'right' : 'left')
              ..add(s);
            if (column.wide) header.clazz('wide');
            return header;
          })));

      _table.add(_thead);
    }

    if (_tbody == null) {
      _tbody = new CoreElement('tbody', classes: 'selectable');
      _table.add(_tbody);
    }

    if (_sortColumn == null) {
      Column column =
          columns.firstWhere((c) => c.supportsSorting, orElse: () => null);
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
    Column<T> column = _sortColumn;
    bool numeric = column.numeric;
    int direction = _sortDirection == SortOrder.ascending ? 1 : -1;

    // update the sort arrows
    for (Column c in columns) {
      CoreElement s = spanForColumn[c];
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
        num one = column.getValue(a);
        num two = column.getValue(b);
        if (one == two) return 0;
        if (_sortDirection == SortOrder.ascending) {
          return one > two ? 1 : -1;
        } else {
          return one > two ? -1 : 1;
        }
      } else {
        String one = column.render(column.getValue(a));
        String two = column.render(column.getValue(b));
        return one.compareTo(two) * direction;
      }
    });
  }

  void _rebuildTable() {
    _clearSelection();

    // Re-build the table.
    List<Element> rowElements = [];

    for (T row in rows) {
      CoreElement tableRow = tr();

      for (Column column in columns) {
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

    _tbody.clear();
    _tbody.element.children.addAll(rowElements);
  }

  CoreElement _selectedElement;
  T _selectedObject;

  void _select(CoreElement elementRow, T object) {
    if (_selectedObject == object) return;

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
    if (!column.supportsSorting) return;

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

  Column(this.title, {this.wide: false});

  String get cssClass => null;

  bool get numeric => false;

  bool get supportsSorting => numeric;

  bool get usesHtml => false;

  /// Get the cell's value from the given [row].
  dynamic getValue(T row);

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

  String toString() => title;
}

enum SortOrder {
  ascending,
  descending,
}

//class SampleData {
//  static SampleData random() {
//    double d = _r.nextDouble();
//    return new SampleData(
//        getLoremFragment(), _r.nextInt(1200), d, d * _r.nextDouble());
//  }
//
//  final String method;
//  final int count;
//  final double usage;
//  final double self;
//
//  SampleData(this.method, this.count, this.usage, this.self);
//}
//
//class SampleColumnMethodName extends Column<SampleData> {
//  SampleColumnMethodName() : super('Name', wide: true);
//
//  dynamic getValue(SampleData row) => row.method;
//}
//
//class SampleColumnCount extends Column<SampleData> {
//  SampleColumnCount() : super('Count');
//
//  bool get numeric => true;
//
//  dynamic getValue(SampleData row) => row.count;
//}
//
//class SampleColumnUsage extends Column<SampleData> {
//  SampleColumnUsage() : super('Usage');
//
//  bool get numeric => true;
//
//  dynamic getValue(SampleData row) => row.usage;
//
//  String render(dynamic value) => percent(value);
//}
