// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter/services.dart';

import '../collapsible_mixin.dart';
import '../common_widgets.dart';
import '../primitives/extent_delegate_list.dart';
import '../primitives/flutter_widgets/linked_scroll_controller.dart';
import '../primitives/trees.dart';
import '../primitives/utils.dart';
import '../ui/search.dart';
import '../ui/utils.dart';
import '../utils.dart';
import 'column_widths.dart';
import 'table_controller.dart';
import 'table_data.dart';

part '_flat_table.dart';
part '_table_column.dart';
part '_table_row.dart';
part '_tree_table.dart';

// TODO(devoncarew): We need to render the selected row with a different
// background color.

typedef IndexedScrollableWidgetBuilder = Widget Function({
  required BuildContext context,
  required LinkedScrollControllerGroup linkedScrollControllerGroup,
  required int index,
  required List<double> columnWidths,
  required bool isPinned,
  required bool enableHoverHandling,
});

typedef TableKeyEventHandler = KeyEventResult Function(
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
    this.preserveVerticalScrollPosition = false,
    this.activeSearchMatchNotifier,
    this.rowItemExtent,
    this.tallHeaders = false,
    this.headerColor,
    this.fillWithEmptyRows = false,
    this.enableHoverHandling = false,
  });

  final TableControllerBase<T> tableController;
  final bool autoScrollContent;
  final List<double> columnWidths;
  final IndexedScrollableWidgetBuilder rowBuilder;
  final double? rowItemExtent;
  final FocusNode? focusNode;
  final TableKeyEventHandler? handleKeyEvent;
  final ValueNotifier<Selection<T?>>? selectionNotifier;
  final ValueListenable<T?>? activeSearchMatchNotifier;
  final bool preserveVerticalScrollPosition;
  final bool tallHeaders;
  final Color? headerColor;
  final bool fillWithEmptyRows;
  final bool enableHoverHandling;

  @override
  DevToolsTableState<T> createState() => DevToolsTableState<T>();
}

@visibleForTesting
class DevToolsTableState<T> extends State<DevToolsTable<T>>
    with AutoDisposeMixin {
  late LinkedScrollControllerGroup _linkedHorizontalScrollControllerGroup;
  late ScrollController scrollController;
  late ScrollController pinnedScrollController;

  late List<T> _data;

  /// An adjusted copy of [widget.columnWidths] where any variable width columns
  /// may be increased so that the sum of all column widths equals the available
  /// screen space.
  ///
  /// This must be calculated where we have access to the Flutter view
  /// constraints (e.g. the [LayoutBuilder] below).
  @visibleForTesting
  late List<double> adjustedColumnWidths;

  @override
  void initState() {
    super.initState();

    _initDataAndAddListeners();

    _linkedHorizontalScrollControllerGroup = LinkedScrollControllerGroup();

    final initialScrollOffset = widget.preserveVerticalScrollPosition
        ? widget.tableController.tableUiState.scrollOffset
        : 0.0;
    widget.tableController.initScrollController(initialScrollOffset);
    scrollController = widget.tableController.verticalScrollController!;

    pinnedScrollController = ScrollController();

    adjustedColumnWidths = List.of(widget.columnWidths);
  }

  @override
  void didUpdateWidget(covariant DevToolsTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final notifiersChanged = widget.tableController.tableData !=
            oldWidget.tableController.tableData ||
        widget.selectionNotifier != oldWidget.selectionNotifier ||
        widget.activeSearchMatchNotifier != oldWidget.activeSearchMatchNotifier;

    if (notifiersChanged) {
      cancelListeners();
      _initDataAndAddListeners();
    }

    adjustedColumnWidths = List.of(widget.columnWidths);
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
          final Selection<T?> selection = selectionNotifier.value;
          final T? node = selection.node;
          final int? Function(T?)? nodeIndexCalculator =
              selection.nodeIndexCalculator;
          final int? nodeIndex = selection.nodeIndex;

          if (selection.scrollIntoView && node != null) {
            final int selectedDisplayRow = nodeIndexCalculator != null
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
    final indexInView = y > scrollController.offset &&
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
    widget.tableController.dispose();
    pinnedScrollController.dispose();
    super.dispose();
  }

  /// The width of all columns in the table with additional padding.
  double get _tableWidthForOriginalColumns {
    var tableWidth = 2 * defaultSpacing;
    final numColumnGroupSpacers =
        widget.tableController.columnGroups?.numSpacers ?? 0;
    final numColumnSpacers =
        widget.tableController.columns.numSpacers - numColumnGroupSpacers;
    tableWidth += numColumnSpacers * columnSpacing;
    tableWidth += numColumnGroupSpacers * columnGroupSpacingWithPadding;
    for (var columnWidth in widget.columnWidths) {
      tableWidth += columnWidth;
    }
    return tableWidth;
  }

  /// Modifies [adjustedColumnWidths] so that any available view space greater
  /// than [_tableWidthForOriginalColumns] is distributed evenly across variable
  /// width columns.
  void _adjustColumnWidthsForViewSize(double viewWidth) {
    final extraSpace = viewWidth - _tableWidthForOriginalColumns;
    if (extraSpace <= 0) {
      adjustedColumnWidths = List.of(widget.columnWidths);
      return;
    }

    final adjustedColumnWidthsByIndex = <int, double>{};

    /// Helper method to evenly distribute [space] among the columns at
    /// [columnIndices].
    ///
    /// This method stores the adjusted width values in
    /// [adjustedColumnWidthsByIndex].
    void evenlyDistributeColumnSizes(List<int> columnIndices, double space) {
      final targetSize = space / columnIndices.length;

      var largestColumnIndex = -1;
      var largestColumnWidth = 0.0;
      for (final index in columnIndices) {
        final columnWidth = widget.columnWidths[index];
        if (columnWidth >= largestColumnWidth) {
          largestColumnIndex = index;
          largestColumnWidth = columnWidth;
        }
      }
      if (targetSize < largestColumnWidth) {
        // We do not have enough extra space to evenly distribute to all
        // columns. Remove the largest column and recurse.
        adjustedColumnWidthsByIndex[largestColumnIndex] = largestColumnWidth;
        final newColumnIndices = List.of(columnIndices)
          ..remove(largestColumnIndex);
        return evenlyDistributeColumnSizes(
          newColumnIndices,
          space - largestColumnWidth,
        );
      }

      for (int i = 0; i < columnIndices.length; i++) {
        final columnIndex = columnIndices[i];
        adjustedColumnWidthsByIndex[columnIndex] = targetSize;
      }
    }

    final variableWidthColumnIndices = <int>[];
    var sumVariableWidthColumnSizes = 0.0;
    for (int i = 0; i < widget.tableController.columns.length; i++) {
      final column = widget.tableController.columns[i];
      if (column.fixedWidthPx == null) {
        variableWidthColumnIndices.add(i);
        sumVariableWidthColumnSizes += widget.columnWidths[i];
      }
    }
    final totalVariableWidthColumnSpace =
        sumVariableWidthColumnSizes + extraSpace;

    evenlyDistributeColumnSizes(
      variableWidthColumnIndices,
      totalVariableWidthColumnSpace,
    );

    adjustedColumnWidths.clear();
    for (int i = 0; i < widget.columnWidths.length; i++) {
      final originalWidth = widget.columnWidths[i];
      final isVariableWidthColumn = variableWidthColumnIndices.contains(i);
      adjustedColumnWidths.add(
        isVariableWidthColumn ? adjustedColumnWidthsByIndex[i]! : originalWidth,
      );
    }
  }

  double _pinnedDataHeight(BoxConstraints tableConstraints) => min(
        widget.rowItemExtent! * pinnedData.length,
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
    maxHeight -= columnHeadersCount *
        (defaultHeaderHeight +
            (widget.tallHeaders ? scaleByFontFactor(densePadding) : 0.0));

    if (pinnedData.isNotEmpty) {
      maxHeight -=
          _pinnedDataHeight(tableConstraints) + ThickDivider.thickDividerHeight;
    }

    return max(_data.length, maxHeight ~/ widget.rowItemExtent!);
  }

  Widget _buildItem(BuildContext context, int index, {bool isPinned = false}) {
    return widget.rowBuilder(
      context: context,
      linkedScrollControllerGroup: _linkedHorizontalScrollControllerGroup,
      index: index,
      columnWidths: adjustedColumnWidths,
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
    final showColumnGroupHeader = columnGroups != null &&
        columnGroups.isNotEmpty &&
        includeColumnGroupHeaders;
    final tableUiState = widget.tableController.tableUiState;
    final sortColumn =
        widget.tableController.columns[tableUiState.sortColumnIndex];
    if (widget.preserveVerticalScrollPosition && scrollController.hasClients) {
      scrollController.jumpTo(tableUiState.scrollOffset);
    }

    // TODO(kenz): add horizontal scrollbar.
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewWidth = constraints.maxWidth;
        _adjustColumnWidthsForViewSize(viewWidth);
        return SelectionArea(
          child: SizedBox(
            width: max(viewWidth, _tableWidthForOriginalColumns),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showColumnGroupHeader)
                  TableRow<T>.tableColumnGroupHeader(
                    linkedScrollControllerGroup:
                        _linkedHorizontalScrollControllerGroup,
                    columnGroups: columnGroups,
                    columnWidths: adjustedColumnWidths,
                    sortColumn: sortColumn,
                    sortDirection: tableUiState.sortDirection,
                    secondarySortColumn:
                        widget.tableController.secondarySortColumn,
                    onSortChanged: widget.tableController.sortDataAndNotify,
                    tall: widget.tallHeaders,
                    backgroundColor: widget.headerColor,
                  ),
                TableRow<T>.tableColumnHeader(
                  key: const Key('Table header'),
                  linkedScrollControllerGroup:
                      _linkedHorizontalScrollControllerGroup,
                  columns: widget.tableController.columns,
                  columnGroups: columnGroups,
                  columnWidths: adjustedColumnWidths,
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
                        itemBuilder: (context, index) => _buildItem(
                          context,
                          index,
                          isPinned: true,
                        ),
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
                        onKeyEvent: (_, event) => widget.handleKeyEvent != null
                            ? widget.handleKeyEvent!(
                                event,
                                scrollController,
                                constraints,
                              )
                            : KeyEventResult.ignored,
                        focusNode: widget.focusNode,
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount:
                              _dataRowCount(constraints, showColumnGroupHeader),
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
        );
      },
    );
  }
}
