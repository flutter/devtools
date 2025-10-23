// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter/services.dart';

import '../primitives/collapsible_mixin.dart';
import '../primitives/extent_delegate_list.dart';
import '../primitives/trees.dart';
import '../primitives/utils.dart';
import '../ui/common_widgets.dart';
import '../ui/search.dart';
import '../ui/utils.dart';
import '../utils/utils.dart';
import 'column_widths.dart';
import 'table_controller.dart';
import 'table_data.dart';

part '_flat_table.dart';
part '_table_column.dart';
part '_table_row.dart';
part '_tree_table.dart';

typedef IndexedScrollableWidgetBuilder =
    Widget Function({
      required BuildContext context,
      required int index,
      required List<double> columnWidths,
      required bool isPinned,
      required bool enableHoverHandling,
    });

typedef TableKeyEventHandler =
    KeyEventResult Function(
      KeyEvent event,
      ScrollController scrollController,
      BoxConstraints constraints,
    );

class Selection<T> {
  Selection({
    this.node,
    this.nodeIndex,
    this.nodeIndexCalculator,
    this.scrollIntoView = false,
  }) : assert(nodeIndex == null || nodeIndexCalculator == null);

  Selection.empty()
    : node = null,
      nodeIndex = null,
      nodeIndexCalculator = null,
      scrollIntoView = true;

  final T? node;
  // TODO (carolynqu): get rid of nodeIndex and only use nodeIndexCalculator, https://github.com/flutter/devtools/issues/4266
  final int? nodeIndex;
  final int? Function(T?)? nodeIndexCalculator;
  final bool scrollIntoView;
}

// TODO(kenz): https://github.com/flutter/devtools/issues/1522. The table code
// needs to be refactored to support flexible column widths.
@visibleForTesting
class DevToolsTable<T> extends StatefulWidget {
  const DevToolsTable({
    super.key,
    required this.tableController,
    required this.columnWidths,
    required this.rowBuilder,
    this.selectionNotifier,
    this.focusNode,
    this.handleKeyEvent,
    this.autoScrollContent = false,
    this.startScrolledAtBottom = false,
    this.preserveVerticalScrollPosition = false,
    this.activeSearchMatchNotifier,
    required this.rowItemExtent,
    this.tallHeaders = false,
    this.headerColor,
    this.fillWithEmptyRows = false,
    this.enableHoverHandling = false,
  });

  final TableControllerBase<T> tableController;
  final bool autoScrollContent;
  final bool startScrolledAtBottom;
  final List<double> columnWidths;
  final IndexedScrollableWidgetBuilder rowBuilder;
  final double rowItemExtent;
  final FocusNode? focusNode;
  final TableKeyEventHandler? handleKeyEvent;
  final ValueNotifier<Selection<T?>>? selectionNotifier;
  final ValueListenable<T?>? activeSearchMatchNotifier;
  final bool preserveVerticalScrollPosition;
  final bool tallHeaders;
  final Color? headerColor;
  final bool fillWithEmptyRows;
  final bool enableHoverHandling;

  static const columnMinWidth = 50.0;

  @override
  DevToolsTableState<T> createState() => DevToolsTableState<T>();
}

@visibleForTesting
class DevToolsTableState<T> extends State<DevToolsTable<T>>
    with AutoDisposeMixin {
  static const _resizingDebounceDuration = Duration(milliseconds: 200);

  late ScrollController scrollController;
  late ScrollController pinnedScrollController;
  late ScrollController _horizontalScrollbarController;

  late List<T> _data;

  late Debouncer _resizingDebouncer;

  @visibleForTesting
  List<double> get columnWidths => _columnWidths;

  late List<double> _columnWidths;

  double? _previousViewWidth;

  @override
  void initState() {
    super.initState();

    _initDataAndAddListeners();

    _resizingDebouncer = Debouncer(duration: _resizingDebounceDuration);

    final initialScrollOffset = widget.preserveVerticalScrollPosition
        ? widget.tableController.tableUiState.scrollOffset
        : 0.0;
    widget.tableController.initScrollController(initialScrollOffset);
    scrollController = widget.tableController.verticalScrollController!;
    _horizontalScrollbarController =
        widget.tableController.horizontalScrollController!;

    if (widget.startScrolledAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(scrollController.autoScrollToBottom(jump: true));
      });
    }

    pinnedScrollController = ScrollController();

    _columnWidths = List.of(widget.columnWidths);
  }

  @override
  void didUpdateWidget(covariant DevToolsTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final notifiersChanged =
        widget.tableController.tableData !=
            oldWidget.tableController.tableData ||
        widget.selectionNotifier != oldWidget.selectionNotifier ||
        widget.activeSearchMatchNotifier != oldWidget.activeSearchMatchNotifier;

    if (notifiersChanged) {
      cancelListeners();
      _initDataAndAddListeners();
    }
  }

  void _initDataAndAddListeners() {
    _data = widget.tableController.tableData.value.data;

    addAutoDisposeListener(widget.tableController.tableData, () {
      setState(() {
        _data = widget.tableController.tableData.value.data;
      });
    });
    _initScrollOnSelectionListener(widget.selectionNotifier);
    _initSearchListener();
  }

  void _initScrollOnSelectionListener(
    ValueNotifier<Selection<T?>>? selectionNotifier,
  ) {
    if (selectionNotifier != null) {
      addAutoDisposeListener(selectionNotifier, () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final selection = selectionNotifier.value;
          final T? node = selection.node;
          final int? Function(T?)? nodeIndexCalculator =
              selection.nodeIndexCalculator;
          final nodeIndex = selection.nodeIndex;

          if (selection.scrollIntoView && node != null) {
            final selectedDisplayRow = nodeIndexCalculator != null
                ? nodeIndexCalculator(node)!
                : nodeIndex!;

            final newPos = selectedDisplayRow * defaultRowHeight;

            maybeScrollToPosition(scrollController, newPos);
          }
        });
      });
    }
  }

  void _initSearchListener() {
    if (widget.activeSearchMatchNotifier != null) {
      addAutoDisposeListener(
        widget.activeSearchMatchNotifier,
        _onActiveSearchChange,
      );
    }
  }

  void _onActiveSearchChange() async {
    final activeSearch = widget.activeSearchMatchNotifier!.value;

    if (activeSearch == null) return;

    final index = _data.indexOf(activeSearch);

    if (index == -1) return;

    final y = index * defaultRowHeight;
    final indexInView =
        y > scrollController.offset &&
        y < scrollController.offset + scrollController.position.extentInside;
    if (!indexInView) {
      await scrollController.animateTo(
        index * defaultRowHeight,
        duration: defaultDuration,
        curve: defaultCurve,
      );
    }
  }

  @override
  void deactivate() {
    if (widget.preserveVerticalScrollPosition) {
      widget.tableController.storeScrollPosition();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    pinnedScrollController.dispose();
    super.dispose();
  }

  void _handleColumnResize(int columnIndex, double newWidth) {
    setState(() {
      _columnWidths[columnIndex] = newWidth;
    });
  }

  /// The width of all columns in the table with additional padding.
  double get _currentTableWidth {
    var tableWidth = 2 * defaultSpacing;
    final numColumnGroupSpacers =
        widget.tableController.columnGroups?.numSpacers ?? 0;
    final numColumnSpacers =
        widget.tableController.columns.numSpacers - numColumnGroupSpacers;
    tableWidth += numColumnSpacers * columnSpacing;
    tableWidth += numColumnGroupSpacers * columnGroupSpacingWithPadding;
    for (final columnWidth in _columnWidths) {
      tableWidth += columnWidth;
    }
    return tableWidth;
  }

  /// Adjusts the column widths to fit the new [viewWidth].
  ///
  /// This method will attempt to distribute any extra space (positive or
  /// negative) amongst the variable-width columns. If there are no
  /// variable-width columns, it will distribute the space amongst all columns.
  void _adjustColumnWidthsForViewSize(double viewWidth) {
    final extraSpace = _currentTableWidth - viewWidth;
    if (extraSpace == 0) {
      return;
    }

    final variableWidthColumnIndices = <(int, double)>[];
    for (int i = 0; i < widget.tableController.columns.length; i++) {
      final column = widget.tableController.columns[i];
      if (column.fixedWidthPx == null) {
        variableWidthColumnIndices.add((i, _columnWidths[i]));
      }
    }

    // If the table contains variable width columns, then distribute the extra
    // space between them. Otherwise, distribute the extra space between all the
    // columns.
    _distributeExtraSpace(
      extraSpace,
      indexedColumns: variableWidthColumnIndices.isNotEmpty
          ? variableWidthColumnIndices
          : _columnWidths.indexed,
    );
  }

  /// Distributes [extraSpace] evenly between the given [indexedColumns].
  ///
  /// The [extraSpace] will be subtracted from each column's width. The
  /// remainder of the division is subtracted from the last column to ensure a
  /// perfect fit.
  ///
  /// This method respects the `minWidthPx` of each column.
  void _distributeExtraSpace(
    double extraSpace, {
    required Iterable<(int, double)> indexedColumns,
  }) {
    final newWidths = List.of(_columnWidths);
    final delta = extraSpace / indexedColumns.length;
    final remainder = extraSpace % indexedColumns.length;

    for (var i = 0; i < indexedColumns.length; i++) {
      final columnIndex = indexedColumns.elementAt(i).$1;
      var newWidth = indexedColumns.elementAt(i).$2;

      newWidth -= delta;
      if (i == indexedColumns.length - 1) {
        newWidth -= remainder;
      }

      final column = widget.tableController.columns[columnIndex];
      newWidths[columnIndex] = max(
        newWidth,
        column.minWidthPx ?? DevToolsTable.columnMinWidth,
      );
    }

    setState(() {
      _columnWidths = newWidths;
    });
  }

  double _pinnedDataHeight(BoxConstraints tableConstraints) => min(
    widget.rowItemExtent * pinnedData.length,
    tableConstraints.maxHeight / 2,
  );

  int _dataRowCount(
    BoxConstraints tableConstraints,
    bool showColumnGroupHeader,
  ) {
    if (!widget.fillWithEmptyRows) {
      return _data.length;
    }

    var maxHeight = tableConstraints.maxHeight;
    final columnHeadersCount = showColumnGroupHeader ? 2 : 1;
    maxHeight -=
        columnHeadersCount *
        (defaultHeaderHeight + (widget.tallHeaders ? densePadding : 0.0));

    if (pinnedData.isNotEmpty) {
      maxHeight -=
          _pinnedDataHeight(tableConstraints) + ThickDivider.thickDividerHeight;
    }

    return max(_data.length, maxHeight ~/ widget.rowItemExtent);
  }

  Widget _buildItem(BuildContext context, int index, {bool isPinned = false}) {
    return widget.rowBuilder(
      context: context,
      index: index,
      columnWidths: _columnWidths,
      isPinned: isPinned,
      enableHoverHandling: widget.enableHoverHandling,
    );
  }

  List<T> get pinnedData => widget.tableController.pinnedData;

  @override
  Widget build(BuildContext context) {
    // If we're at the end already, scroll to expose the new content.
    if (widget.autoScrollContent) {
      if (scrollController.hasClients && scrollController.atScrollBottom) {
        unawaited(scrollController.autoScrollToBottom());
      }
    }

    final columnGroups = widget.tableController.columnGroups;
    final includeColumnGroupHeaders =
        widget.tableController.includeColumnGroupHeaders;
    final showColumnGroupHeader =
        columnGroups != null &&
        columnGroups.isNotEmpty &&
        includeColumnGroupHeaders;
    final tableUiState = widget.tableController.tableUiState;
    final sortColumn =
        widget.tableController.columns[tableUiState.sortColumnIndex];
    if (widget.preserveVerticalScrollPosition && scrollController.hasClients) {
      scrollController.jumpTo(tableUiState.scrollOffset);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewWidth = constraints.maxWidth;
        if (_previousViewWidth != null && viewWidth != _previousViewWidth) {
          _resizingDebouncer.run(
            () => _adjustColumnWidthsForViewSize(viewWidth),
          );
        }
        _previousViewWidth = viewWidth;
        return Scrollbar(
          controller: _horizontalScrollbarController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _horizontalScrollbarController,
            child: SelectionArea(
              child: SizedBox(
                width: max(viewWidth, _currentTableWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showColumnGroupHeader)
                      TableRow<T>.tableColumnGroupHeader(
                        columnGroups: columnGroups,
                        columnWidths: _columnWidths,
                        sortColumn: sortColumn,
                        sortDirection: tableUiState.sortDirection,
                        secondarySortColumn:
                            widget.tableController.secondarySortColumn,
                        onSortChanged: widget.tableController.sortDataAndNotify,
                        tall: widget.tallHeaders,
                        backgroundColor: widget.headerColor,
                      ),
                    // TODO(kenz): add support for excluding column headers.
                    TableRow<T>.tableColumnHeader(
                      key: const Key('Table header'),
                      columns: widget.tableController.columns,
                      columnGroups: columnGroups,
                      columnWidths: _columnWidths,
                      sortColumn: sortColumn,
                      sortDirection: tableUiState.sortDirection,
                      secondarySortColumn:
                          widget.tableController.secondarySortColumn,
                      onSortChanged: widget.tableController.sortDataAndNotify,
                      tall: widget.tallHeaders,
                      backgroundColor: widget.headerColor,
                    ),
                    if (pinnedData.isNotEmpty) ...[
                      SizedBox(
                        height: _pinnedDataHeight(constraints),
                        child: Scrollbar(
                          thumbVisibility: true,
                          controller: pinnedScrollController,
                          child: ListView.builder(
                            controller: pinnedScrollController,
                            itemCount: pinnedData.length,
                            itemExtent: widget.rowItemExtent,
                            itemBuilder: (context, index) =>
                                _buildItem(context, index, isPinned: true),
                          ),
                        ),
                      ),
                      const ThickDivider(),
                    ],
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: scrollController,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (a) => widget.focusNode?.requestFocus(),
                          child: Focus(
                            autofocus: true,
                            onKeyEvent: (_, event) =>
                                widget.handleKeyEvent != null
                                ? widget.handleKeyEvent!(
                                    event,
                                    scrollController,
                                    constraints,
                                  )
                                : KeyEventResult.ignored,
                            focusNode: widget.focusNode,
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: _dataRowCount(
                                constraints,
                                showColumnGroupHeader,
                              ),
                              itemExtent: widget.rowItemExtent,
                              itemBuilder: _buildItem,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
