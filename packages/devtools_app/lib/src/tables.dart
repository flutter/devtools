// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:html_shim/html.dart';

import 'package:meta/meta.dart';

import 'framework/framework.dart';
import 'table_data.dart';
import 'trees.dart';
import 'ui/custom.dart';
import 'ui/elements.dart';
import 'ui/primer.dart';

class HoverCell<T> extends HoverCellData<T> {
  HoverCell(this.cell, T data) : super(data);

  final CoreElement cell;
}

class Table<T> with SetStateMixin implements TableDataClient<T> {
  factory Table() => Table._(TableData<T>(), null, false);

  factory Table.virtual({double rowHeight = 29.0}) =>
      Table._(TableData<T>(), rowHeight, true);

  Table._(
    this.model,
    this.rowHeight,
    this.isVirtual, {
    bool overflowAuto = false,
  }) : assert(model.client == null) {
    model.client = this;
    element = isVirtual
        ? div(
            a: 'flex',
            c: '${overflowAuto ? 'overflow-auto' : 'overflow-y'} '
                'table-border table-virtual',
          )
        : div(a: 'flex', c: 'overflow-y table-border');
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
          model.handleLeftKey();
          break;
        case KeyCode.RIGHT:
          model.handleRightKey();
          break;
        default:
          break;
      }

      if (indexOffset == null) {
        return;
      }

      e.preventDefault();

      // Get the index of the currently selected row.
      final int currentIndex = model.selectedObjectIndex;
      // Offset it, or select index 0 if there was no prior selection.
      int newIndex = currentIndex == null ? 0 : (currentIndex + indexOffset);
      // Clamp to the first/last row.
      final int maxRowIndex = (model.data?.length ?? 1) - 1;
      newIndex = newIndex.clamp(0, maxRowIndex);

      selectByIndex(newIndex);
    });

    _spacerBeforeVisibleRows = CoreElement('tr');
    _spacerAfterVisibleRows = CoreElement('tr');

    element.onScroll.listen((_) => model.scheduleRebuild());

    // Monitor the table changing size.
    _resizeObserver = ResizeObserver(_resize);
    _resizeObserver.observe(element.element);
  }

  /// Detect of any table resize - rebuild the visible changes.
  // TODO(terry): Enable when JSArray to entries as List in dart:html fixed.
  //  void _resize(List<ResizeObserverEntry> entries, ResizeObserver observer) {
  void _resize(var entries, ResizeObserver observer) {
    // If table doesn't yet exist we're done.
    if (_thead == null) return;

    // Should be the table.
    // TODO(terry): Enble when JSArray to List<ResizeObserverEntry> convert.
    // assert(entries.first.target == element.element);

    // Update the visible rows when table resized (grown).
    model.scheduleRebuild();
  }

  final double rowHeight;
  final bool isVirtual;

  ResizeObserver _resizeObserver;

  void dispose() {
    model?.dispose();
    _resizeObserver?.disconnect();
  }

  final TableData<T> model;
  CoreElement element;

  final CoreElement _table = CoreElement('table')
    ..clazz('full-width')
    ..setAttribute('tabIndex', '0');
  CoreElement _thead;
  CoreElement _tbody;

  CoreElement _spacerBeforeVisibleRows;
  CoreElement _spacerAfterVisibleRows;
  final CoreElement _dummyRowToForceAlternatingColor = CoreElement('tr')
    ..display = 'none';

  final Map<ColumnData<T>, CoreElement> _spanForColumn =
      <ColumnData<T>, CoreElement>{};
  final Map<Element, T> _dataForRow = <Element, T>{};
  final Map<int, CoreElement> _rowForIndex = <int, CoreElement>{};

  ColumnRenderer<T> getColumnRenderer(ColumnData<T> columnModel) {
    return ColumnRenderer(columnModel);
  }

  @override
  void onSetRows() {
    if (_thead == null) {
      _thead = CoreElement('thead')
        ..add(tr()
          ..add(model.columns.map((ColumnData<T> column) {
            final CoreElement s = span(
                text: column.title,
                c: 'interactable${column.supportsSorting ? ' sortable' : ''}');
            s.click(() => model.onColumnClicked(column));
            _spanForColumn[column] = s;

            final CoreElement header =
                th(c: 'sticky-top ${getColumnRenderer(column).alignmentCss}')
                  ..add(s);
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
  }

  @override
  void onColumnSortChanged(ColumnData<T> column, SortOrder sortDirection) {
    // Update the UI to reflect the new column sort order.
    // The base class will sort the actual data.

    // update the sort arrows
    for (ColumnData<T> c in model.columns) {
      final CoreElement s = _spanForColumn[c];
      if (c == column) {
        s.toggleClass('up', sortDirection == SortOrder.ascending);
        s.toggleClass('down', sortDirection != SortOrder.ascending);
      } else {
        s.toggleClass('up', false);
        s.toggleClass('down', false);
      }
    }
  }

  @override
  void rebuildTable() {
    // If we've never had any data set, we don't need to (and can't - since all
    // the elements aren't created) rebuild.
    if (model.data == null) {
      return;
    }

    if (isVirtual) {
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

    final data = model.data;

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
        lastRenderedRowExclusive: model.data?.length ?? 0);
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
      final T dataObject = model.data[index];
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
        tableRow.click(() {
          final rowElement = tableRow.element;
          final dataForRow = _dataForRow[rowElement];
          selectRow(rowElement, model.data.indexOf(dataForRow));
          // TODO(kenzie): we should do less work on selection.
          model.scheduleRebuild();
        });
      }

      if (rowHeight != null) {
        tableRow.height = '${rowHeight}px';
        tableRow.clazz('overflow-y');
      }

      int currentColumnIndex = 0;
      for (ColumnData<T> column in model.columns) {
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

        final columnRenderer = getColumnRenderer(column);
        tableCell.clazz(columnRenderer.alignmentCss);

        columnRenderer.renderToElement(tableCell, dataObject);

        if (!isReusableColumn) {
          tableRow.add(tableCell);
        }
      }

      // If this row represents our selected object, highlight it.
      if (dataObject == model.selectedObject) {
        _select(tableRow.element, model.selectedObject, index);
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

  void _select(Element row, T object, int index) {
    if (_tbody != null) {
      for (Element row in _tbody.element.querySelectorAll('.selected')) {
        row.classes.remove('selected');
      }
    }

    if (row != null) {
      row.classes.add('selected');
    }

    model.setSelection(object, index);
  }

  void _selectCoreElement(CoreElement coreElement, T object, int index) {
    model.selectElementController.add(HoverCell<T>(coreElement, object));
  }

  /// Selects by index. Note: This is index of the row as it's rendered
  /// and not necessarily for rows[] since it may be being rendered in reverse.
  /// This way, +1 will always move down the visible table.
  /// scrollBehaviour is a string as defined for the HTML scrollTo() method
  /// https://developer.mozilla.org/en-US/docs/Web/API/Window/scrollTo (eg.
  /// `smooth`, `instance`, `auto`).
  @override
  void selectByIndex(
    int newIndex, {
    bool keepVisible = true,
    String scrollBehavior = 'smooth',
  }) {
    final CoreElement row = _rowForIndex[newIndex];
    final T dataObject = model.data[newIndex];
    _select(row?.element, dataObject, newIndex);

    if (keepVisible) {
      scrollToIndex(newIndex, scrollBehavior: scrollBehavior);
    }
  }

  @override
  void scrollToIndex(int rowIndex, {String scrollBehavior = 'smooth'}) {
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

  @override
  void clearSelection() => _select(null, null, null);
}

class ColumnRenderer<T> {
  ColumnRenderer(this.model);

  final ColumnData<T> model;

  String get alignmentCss => _getAlignmentCss(model.alignment);

  void renderToElement(CoreElement cell, T dataObject) {
    final String content = model.render(model.getDisplayValue(dataObject));
    if (model.usesHtml) {
      cell.setInnerHtml(content);
    } else {
      cell.text = content;
    }
    cell.tooltip = model.getTooltip(dataObject);
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

class TreeColumnRenderer<T extends TreeNode<T>> extends ColumnRenderer<T> {
  TreeColumnRenderer(TreeColumnData<T> model) : super(model);

  @override
  TreeColumnData<T> get model => super.model;

  @override
  void renderToElement(CoreElement cell, T dataObject) {
    final container = div()
      ..layoutHorizontal()
      ..flex()
      // Add spacer to beginning of element that reflects tree structure.
      ..add(div()
        ..element.style.minWidth = '${model.getNodeIndentPx(dataObject)}px');

    if (dataObject.isExpandable) {
      final TreeToggle treeToggle = TreeToggle(forceOpen: dataObject.isExpanded)
        ..onOpen.listen((isOpen) {
          if (isOpen) {
            model.nodeExpandedController.add(dataObject);
          } else {
            model.nodeCollapsedController.add(dataObject);
          }
        });
      container.add(treeToggle);
    }

    container.add(div(text: model.render(model.getDisplayValue(dataObject))));

    cell
      ..clear()
      ..add(container)
      ..tooltip = model.getTooltip(dataObject);
  }
}

class TreeTable<T extends TreeNode<T>> extends Table<T> {
  factory TreeTable() => TreeTable._(TreeTableData<T>(), null, false);

  factory TreeTable.virtual({double rowHeight = 29.0}) =>
      TreeTable._(TreeTableData<T>(), rowHeight, true);

  TreeTable._(TreeTableData<T> model, double rowHeight, bool isVirtual)
      : super._(model, rowHeight, isVirtual, overflowAuto: true);

  @override
  TreeTableData<T> get model => super.model;

  @override
  ColumnRenderer<T> getColumnRenderer(ColumnData<T> columnModel) {
    return columnModel is TreeColumnData<T>
        ? TreeColumnRenderer(columnModel)
        : ColumnRenderer(columnModel);
  }
}

class TreeTableToolbar<T extends TreeNode<T>> extends CoreElement {
  TreeTableToolbar() : super('div') {
    add(div(c: 'btn-group')
      ..add([
        PButton('Expand all')
          ..small()
          ..click(_expandAll),
        PButton('Collapse all')
          ..small()
          ..click(_collapseAll),
      ]));
  }

  TreeTable<T> treeTable;

  void _expandAll() {
    treeTable.model.expandAll();
  }

  void _collapseAll() {
    treeTable.model.collapseAll();
  }
}
