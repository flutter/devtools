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
import '../primitives/flutter_widgets/linked_scroll_controller.dart';
import '../primitives/trees.dart';
import '../primitives/utils.dart';
import '../ui/search.dart';
import '../ui/utils.dart';
import 'column_widths.dart';
import 'table_controller.dart';
import 'table_data.dart';

// TODO(devoncarew): We need to render the selected row with a different
// background color.

/// The height for rows in the table.
double get defaultRowHeight => scaleByFontFactor(32.0);

typedef IndexedScrollableWidgetBuilder = Widget Function({
  required BuildContext context,
  required LinkedScrollControllerGroup linkedScrollControllerGroup,
  required int index,
  required List<double> columnWidths,
  required bool isPinned,
});

typedef TableKeyEventHandler = KeyEventResult Function(
  RawKeyEvent event,
  ScrollController scrollController,
  BoxConstraints constraints,
);

enum ScrollKind {
  up,
  down,
  parent,
}

/// A [FlatTable] widget that is searchable.
///
/// The table requires a [searchController], which is responsible for feeding
/// information about search matches and the active search match to the table.
///
/// This table will automatically refresh search matches on the
/// [searchController] after sort operations that are triggered from the table.
class SearchableFlatTable<T extends SearchableDataMixin> extends FlatTable {
  SearchableFlatTable({
    super.key,
    required SearchControllerMixin<T> searchController,
    required super.keyFactory,
    required super.data,
    required super.dataKey,
    required super.columns,
    required super.defaultSortColumn,
    required super.defaultSortDirection,
    super.secondarySortColumn,
    super.sortOriginalData = false,
    super.pinBehavior = FlatTablePinBehavior.none,
    super.columnGroups,
    super.autoScrollContent = false,
    super.onItemSelected,
    super.preserveVerticalScrollPosition = false,
    super.includeColumnGroupHeaders = true,
    super.sizeColumnsToFit = true,
    super.selectionNotifier,
  }) : super(
          searchMatchesNotifier: searchController.searchMatches,
          activeSearchMatchNotifier: searchController.activeSearchMatch,
          onDataSorted: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            // This needs to be in a post frame callback so that the search
            // matches are not updated in the middle of a table build.
            searchController.refreshSearchMatches();
          }),
        );
}

/// A table that displays in a collection of [data], based on a collection of
/// [ColumnData].
///
/// The [ColumnData] gives this table information about how to size its columns,
/// and how to present each row of `data`.
class FlatTable<T> extends StatefulWidget {
  FlatTable({
    Key? key,
    required this.keyFactory,
    required this.data,
    required this.dataKey,
    required this.columns,
    this.columnGroups,
    this.autoScrollContent = false,
    this.onItemSelected,
    required this.defaultSortColumn,
    required this.defaultSortDirection,
    this.onDataSorted,
    this.sortOriginalData = false,
    this.pinBehavior = FlatTablePinBehavior.none,
    this.secondarySortColumn,
    this.searchMatchesNotifier,
    this.activeSearchMatchNotifier,
    this.preserveVerticalScrollPosition = false,
    this.includeColumnGroupHeaders = true,
    this.tallHeaders = false,
    this.sizeColumnsToFit = true,
    this.headerColor,
    this.fillerRowCount = 0,
    ValueNotifier<T?>? selectionNotifier,
  })  : selectionNotifier = selectionNotifier ?? ValueNotifier<T?>(null),
        super(key: key);

  /// List of columns to display.
  ///
  /// These [ColumnData] elements should be defined as static
  /// OR if they cannot be defined as static,
  /// they should not manage stateful data.
  ///
  /// [FlatTableState.didUpdateWidget] checks if the columns have
  /// changed before re-initializing the table controller,
  /// and the columns are compared by title only.
  /// See also [FlatTableState. _tableConfigurationChanged].
  final List<ColumnData<T>> columns;

  final List<ColumnGroup>? columnGroups;

  /// Whether the columns for this table should be sized so that the entire
  /// table fits in view (e.g. so that there is no horizontal scrolling).
  final bool sizeColumnsToFit;

  // TODO(kenz): should we enable this behavior by default? Does it ever matter
  // to preserve the order of the original data passed to a flat table?
  /// Whether table sorting should sort the original data list instead of
  /// creating a copy.
  final bool sortOriginalData;

  /// Determines if the headers for column groups should be rendered.
  ///
  /// If set to false and `columnGroups` is non-null and non-empty, only
  /// the vertical dividing lines will be drawn for each column group boundary.
  final bool includeColumnGroupHeaders;

  /// Whether the table headers should be slightly taller than the table rows to
  /// support multiline text.
  final bool tallHeaders;

  /// The background color of the header.
  ///
  /// If null, defaults to `Theme.of(context).canvasColor`.
  final Color? headerColor;

  /// The number of empty filler rows.
  final int fillerRowCount;

  /// Data set to show as rows in this table.
  final List<T> data;

  /// Unique key for the data shown in this table.
  ///
  /// This key will be used to restore things like sort column, sort direction,
  /// and scroll position for this table (when [preserveVerticalScrollPosition]
  /// is true).
  ///
  /// We use [TableUiStateStore] to store [_TableUiState] by this key so that
  /// we can save and restore this state without having to keep [State] or table
  /// controller objects alive.
  final String dataKey;

  /// Auto-scrolling the table to keep new content visible.
  final bool autoScrollContent;

  /// Factory that creates keys for each row in this table.
  final Key Function(T data) keyFactory;

  /// Callback that, when non-null, will be called on each table row selection.
  final ItemSelectedCallback<T?>? onItemSelected;

  /// Determines how elements that request to be pinned are displayed.
  ///
  /// Defaults to [FlatTablePinBehavior.none], which disables pinnning.
  final FlatTablePinBehavior pinBehavior;

  /// The default sort column for this table.
  ///
  /// This sort column is passed along to [TreeTableState.tableController],
  /// which uses [defaultSortColumn] for the starting value in
  /// [TableControllerBase.tableUiState].
  final ColumnData<T> defaultSortColumn;

  /// The default [SortDirection] for this table.
  ///
  /// This [SortDirection] is passed along to [TreeTableState.tableController],
  /// which uses [defaultSortDirection] for the starting value in
  /// [TableControllerBase.tableUiState].
  final SortDirection defaultSortDirection;

  /// The secondary sort column to be used in the sorting algorithm provided by
  /// [TableControllerBase.sortDataAndNotify].
  final ColumnData<T>? secondarySortColumn;

  /// Callback that will be called after each table sort operation.
  final VoidCallback? onDataSorted;

  /// Notifies with the list of data items that should be marked as search
  /// matches.
  final ValueListenable<List<T>>? searchMatchesNotifier;

  /// Notifies with the data item that should be marked as the active search
  /// match.
  final ValueListenable<T?>? activeSearchMatchNotifier;

  /// Stores the selected data item (the selected row) for this table.
  ///
  /// This notifier's value will be updated when a row of the table is selected.
  final ValueNotifier<T?> selectionNotifier;

  /// Whether the vertical scroll position for this table should be preserved for
  /// each data set.
  ///
  /// This should be set to true if the table is not disposed and completely
  /// rebuilt when changing from one data set to another.
  final bool preserveVerticalScrollPosition;

  @override
  FlatTableState<T> createState() => FlatTableState<T>();
}

@visibleForTesting
class FlatTableState<T> extends State<FlatTable<T>> with AutoDisposeMixin {
  FlatTableController<T> get tableController => _tableController!;
  FlatTableController<T>? _tableController;

  @override
  void initState() {
    super.initState();
    _setUpTableController();
    addAutoDisposeListener(tableController.tableData);

    if (tableController.pinBehavior != FlatTablePinBehavior.none &&
        this is! State<FlatTable<PinnableListEntry>>) {
      throw StateError('$T must implement PinnableListEntry');
    }
  }

  @override
  void didUpdateWidget(FlatTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tableConfigurationChanged(oldWidget, widget)) {
      _setUpTableController();
    } else if (!collectionEquals(oldWidget.data, widget.data)) {
      _setUpTableController(reset: false);
    }
  }

  @override
  void dispose() {
    _tableController = null;
    super.dispose();
  }

  /// Sets up the [tableController] for the property values in [widget].
  ///
  /// [reset] determines whether or not we should re-initialize
  /// [_tableController], which should only happen when the core table
  /// configuration (columns & column groups) has changed.
  ///
  /// See [_tableConfigurationChanged].
  void _setUpTableController({bool reset = true}) {
    final shouldResetController = reset || _tableController == null;
    if (shouldResetController) {
      _tableController = FlatTableController<T>(
        columns: widget.columns,
        defaultSortColumn: widget.defaultSortColumn,
        defaultSortDirection: widget.defaultSortDirection,
        secondarySortColumn: widget.secondarySortColumn,
        columnGroups: widget.columnGroups,
        includeColumnGroupHeaders: widget.includeColumnGroupHeaders,
        pinBehavior: widget.pinBehavior,
        sizeColumnsToFit: widget.sizeColumnsToFit,
        sortOriginalData: widget.sortOriginalData,
        onDataSorted: widget.onDataSorted,
      );
    }

    if (widget.preserveVerticalScrollPosition) {
      // Order matters - this must be called before [tableController.setData]
      tableController.storeScrollPosition();
    }

    tableController
      ..setData(widget.data, widget.dataKey)
      ..pinBehavior = widget.pinBehavior;
  }

  /// Whether the core table configuration has changed, determined by checking
  /// the equality of columns and column groups.
  bool _tableConfigurationChanged(
    FlatTable<T> oldWidget,
    FlatTable<T> newWidget,
  ) {
    final columnsChanged = !collectionEquals(
          oldWidget.columns.map((c) => c.title),
          newWidget.columns.map((c) => c.title),
        ) ||
        !collectionEquals(
          oldWidget.columnGroups?.map((c) => c.title),
          newWidget.columnGroups?.map((c) => c.title),
        );
    return columnsChanged;
  }

  @override
  Widget build(BuildContext context) {
    Widget buildTable(List<double> columnWidths) => _Table<T>(
          tableController: tableController,
          columnWidths: columnWidths,
          autoScrollContent: widget.autoScrollContent,
          rowBuilder: _buildRow,
          activeSearchMatchNotifier: widget.activeSearchMatchNotifier,
          rowItemExtent: defaultRowHeight,
          preserveVerticalScrollPosition: widget.preserveVerticalScrollPosition,
          tallHeaders: widget.tallHeaders,
          headerColor: widget.headerColor,
          fillerRowCount: widget.fillerRowCount,
        );
    if (widget.sizeColumnsToFit || tableController.columnWidths == null) {
      return LayoutBuilder(
        builder: (context, constraints) => buildTable(
          tableController.computeColumnWidthsSizeToFit(
            constraints.maxWidth,
          ),
        ),
      );
    }
    return buildTable(tableController.columnWidths!);
  }

  Widget _buildRow({
    required BuildContext context,
    required LinkedScrollControllerGroup linkedScrollControllerGroup,
    required int index,
    required List<double> columnWidths,
    required bool isPinned,
  }) {
    final pinnedData = tableController.pinnedData;
    final data = isPinned ? pinnedData : tableController.tableData.value.data;
    if (index >= data.length) {
      return TableRow<T>.filler(
        linkedScrollControllerGroup: linkedScrollControllerGroup,
        columns: tableController.columns,
        columnGroups: tableController.columnGroups,
        columnWidths: columnWidths,
        backgroundColor: alternatingColorForIndex(
          index,
          Theme.of(context).colorScheme,
        ),
      );
    }

    final node = data[index];
    return ValueListenableBuilder<T?>(
      valueListenable: widget.selectionNotifier,
      builder: (context, selected, _) {
        return TableRow<T>(
          key: widget.keyFactory(node),
          linkedScrollControllerGroup: linkedScrollControllerGroup,
          node: node,
          onPressed: (T? selection) {
            widget.selectionNotifier.value = selection;
            if (widget.onItemSelected != null && selection != null) {
              widget.onItemSelected!(selection);
            }
          },
          columns: tableController.columns,
          columnGroups: tableController.columnGroups,
          columnWidths: columnWidths,
          backgroundColor: alternatingColorForIndex(
            index,
            Theme.of(context).colorScheme,
          ),
          isSelected: node != null && node == selected,
          searchMatchesNotifier: widget.searchMatchesNotifier,
          activeSearchMatchNotifier: widget.activeSearchMatchNotifier,
        );
      },
    );
  }
}

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

// TODO(https://github.com/flutter/devtools/issues/1657)

/// A table that shows [TreeNode]s.
///
/// This takes in a collection of [dataRoots], and a collection of [ColumnData].
/// It takes at most one [TreeColumnData].
///
/// The [ColumnData] gives this table information about how to size its
/// columns, how to present each row of `data`, and which rows to show.
///
/// To lay the contents out, this table's [TreeTableState] creates a flattened
/// list of the tree hierarchy. It then uses the nesting level of the
/// deepest row in [dataRoots] to determine how wide to make the [treeColumn].
///
/// If [dataRoots.length] > 1, there are multiple trees in this tree table. In
/// this case, tree table operations (expand all, collapse all, sort, etc.) will
/// be applied to every tree.
class TreeTable<T extends TreeNode<T>> extends StatefulWidget {
  TreeTable({
    Key? key,
    required this.keyFactory,
    required this.dataRoots,
    required this.dataKey,
    required this.columns,
    required this.treeColumn,
    required this.defaultSortColumn,
    required this.defaultSortDirection,
    this.secondarySortColumn,
    this.autoExpandRoots = false,
    this.preserveVerticalScrollPosition = false,
    this.displayTreeGuidelines = false,
    this.tallHeaders = false,
    this.headerColor,
    ValueNotifier<Selection<T?>>? selectionNotifier,
  })  : selectionNotifier = selectionNotifier ??
            ValueNotifier<Selection<T?>>(Selection.empty()),
        assert(columns.contains(treeColumn)),
        assert(columns.contains(defaultSortColumn)),
        super(key: key);

  /// Factory that creates keys for each row in this table.
  final Key Function(T) keyFactory;

  /// The tree structures of rows to show in this table.
  ///
  /// Each root in [dataRoots] will be a top-level entry in the table. Depending
  /// on the expanded / collapsed state of each root and its children,
  /// additional table rows will be present in the table.
  final List<T> dataRoots;

  /// Unique key for the data shown in this table.
  ///
  /// This key will be used to restore things like sort column, sort direction,
  /// and scroll position for this table (when [preserveVerticalScrollPosition]
  /// is true).
  ///
  /// We use [TableUiStateStore] to store [_TableUiState] by this key so that
  /// we can save and restore this state without having to keep [State] or table
  /// controller objects alive.
  final String dataKey;

  /// The columns to show in this table.
  final List<ColumnData<T>> columns;

  /// The column of the table to treat as expandable.
  final TreeColumnData<T> treeColumn;

  /// The default sort column for this table.
  ///
  /// This sort column is passed along to [TreeTableState.tableController],
  /// which uses [defaultSortColumn] for the starting value in
  /// [TableControllerBase.tableUiState].
  final ColumnData<T> defaultSortColumn;

  /// The default [SortDirection] for this table.
  ///
  /// This [SortDirection] is passed along to [TreeTableState.tableController],
  /// which uses [defaultSortDirection] for the starting value in
  /// [TableControllerBase.tableUiState].
  final SortDirection defaultSortDirection;

  /// The secondary sort column to be used in the sorting algorithm provided by
  /// [TableControllerBase.sortDataAndNotify].
  final ColumnData<T>? secondarySortColumn;

  /// Stores the selected data item (the selected row) for this table.
  ///
  /// This notifier's value will be updated when a row of the table is selected.
  final ValueNotifier<Selection<T?>> selectionNotifier;

  /// Whether the data roots in this table should be automatically expanded.
  final bool autoExpandRoots;

  /// Whether the vertical scroll position for this table should be preserved for
  /// each data set.
  ///
  /// This should be set to true if the table is not disposed and completely
  /// rebuilt when changing from one data set to another.
  final bool preserveVerticalScrollPosition;

  /// Determines whether or not guidelines should be rendered in tree columns.
  final bool displayTreeGuidelines;

  /// Whether the table headers should be slightly taller than the table rows to
  /// support multiline text.
  final bool tallHeaders;

  /// The background color of the header.
  ///
  /// If null, defaults to `Theme.of(context).canvasColor`.
  final Color? headerColor;

  @override
  TreeTableState<T> createState() => TreeTableState<T>();
}

class TreeTableState<T extends TreeNode<T>> extends State<TreeTable<T>>
    with TickerProviderStateMixin, AutoDisposeMixin {
  FocusNode? get focusNode => _focusNode;
  late FocusNode _focusNode;

  TreeTableController<T> get tableController => _tableController!;
  TreeTableController<T>? _tableController;

  late List<T> _data;

  VoidCallback? _selectionListener;

  @override
  void initState() {
    super.initState();
    _setUpTableController();

    _data = tableController.tableData.value.data;
    addAutoDisposeListener(tableController.tableData, () {
      setState(() {
        _data = tableController.tableData.value.data;
      });
    });

    _initSelectionListener();

    _focusNode = FocusNode(debugLabel: 'table');
    autoDisposeFocusNode(_focusNode);
  }

  @override
  void didUpdateWidget(TreeTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tableConfigurationChanged(oldWidget, widget)) {
      _setUpTableController();
    } else {
      _setUpTableController(reset: false);
    }

    if (oldWidget.selectionNotifier != widget.selectionNotifier) {
      _initSelectionListener();
    }
  }

  @override
  void dispose() {
    _tableController = null;
    super.dispose();
  }

  /// Sets up the [tableController] for the property values in [widget].
  ///
  /// [reset] determines whether or not we should re-initialize
  /// [_tableController], which should only happen when the core table
  /// configuration (columns & column groups) has changed.
  ///
  /// See [_tableConfigurationChanged].
  void _setUpTableController({bool reset = true}) {
    final shouldResetController = reset || _tableController == null;
    if (shouldResetController) {
      _tableController = TreeTableController<T>(
        columns: widget.columns,
        defaultSortColumn: widget.defaultSortColumn,
        defaultSortDirection: widget.defaultSortDirection,
        secondarySortColumn: widget.secondarySortColumn,
        treeColumn: widget.treeColumn,
        autoExpandRoots: widget.autoExpandRoots,
      );
    }

    if (widget.preserveVerticalScrollPosition) {
      // Order matters - this must be called before [tableController.setData]
      tableController.storeScrollPosition();
    }

    tableController.setData(widget.dataRoots, widget.dataKey);
  }

  /// Whether the core table configuration has changed, determined by checking
  /// the equality of columns and column groups.
  bool _tableConfigurationChanged(
    TreeTable<T> oldWidget,
    TreeTable<T> newWidget,
  ) {
    final columnsChanged = !collectionEquals(
          oldWidget.columns.map((c) => c.title),
          newWidget.columns.map((c) => c.title),
        ) ||
        oldWidget.treeColumn.title != newWidget.treeColumn.title;
    return columnsChanged;
  }

  void _initSelectionListener() {
    cancelListener(_selectionListener);
    _selectionListener = () {
      final node = widget.selectionNotifier.value.node;
      if (node != null) {
        setState(() {
          expandParents(node.parent);
        });
      }
    };
    addAutoDisposeListener(widget.selectionNotifier, _selectionListener);
  }

  void expandParents(T? parent) {
    if (parent == null) return;

    if (parent.parent?.index != -1) {
      expandParents(parent.parent);
    }

    if (!parent.isExpanded) {
      _toggleNode(parent);
    }
  }

  void _onItemPressed(T node, int nodeIndex) {
    // Rebuilds the table whenever the tree structure has been updated.
    widget.selectionNotifier.value = Selection(
      node: node,
      nodeIndex: nodeIndex,
    );

    _toggleNode(node);
  }

  void _toggleNode(T node) {
    if (!node.isExpandable) {
      node.leaf();
      return;
    }

    setState(() {
      if (node.isExpanded) {
        node.collapse();
      } else {
        node.expand();
      }
    });

    tableController.setDataAndNotify();
  }

  @override
  Widget build(BuildContext context) {
    return _Table<T>(
      tableController: tableController,
      columnWidths: tableController.columnWidths!,
      rowBuilder: _buildRow,
      rowItemExtent: defaultRowHeight,
      focusNode: _focusNode,
      handleKeyEvent: _handleKeyEvent,
      selectionNotifier: widget.selectionNotifier,
      preserveVerticalScrollPosition: widget.preserveVerticalScrollPosition,
      tallHeaders: widget.tallHeaders,
      headerColor: widget.headerColor,
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required LinkedScrollControllerGroup linkedScrollControllerGroup,
    required int index,
    required List<double> columnWidths,
    required bool isPinned,
  }) {
    Widget rowForNode(T node) {
      final selection = widget.selectionNotifier.value;
      node.index = index;
      return TableRow<T>(
        key: widget.keyFactory(node),
        linkedScrollControllerGroup: linkedScrollControllerGroup,
        node: node,
        onPressed: (item) => _onItemPressed(item, index),
        backgroundColor: alternatingColorForIndex(
          index,
          Theme.of(context).colorScheme,
        ),
        columns: tableController.columns,
        columnWidths: columnWidths,
        expandableColumn: tableController.treeColumn,
        isSelected: selection.node != null && selection.node == node,
        isExpanded: node.isExpanded,
        isExpandable: node.isExpandable,
        isShown: node.shouldShow(),
        displayTreeGuidelines: widget.displayTreeGuidelines,
      );
    }

    return rowForNode(_data[index]);
  }

  KeyEventResult _handleKeyEvent(
    RawKeyEvent event,
    ScrollController scrollController,
    BoxConstraints constraints,
  ) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;

    // Exit early if we aren't handling the key
    if (![
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ].contains(event.logicalKey)) return KeyEventResult.ignored;

    // If there is no selected node, choose the first one.
    if (widget.selectionNotifier.value.node == null) {
      widget.selectionNotifier.value = Selection(
        node: _data[0],
        nodeIndex: 0,
      );
    }

    final selection = widget.selectionNotifier.value;
    assert(selection.node == _data[selection.nodeIndex!]);

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(ScrollKind.down, scrollController, constraints.maxHeight);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(ScrollKind.up, scrollController, constraints.maxHeight);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // On left arrow collapse the row if it is expanded. If it is not, move
      // selection to its parent.
      if (selection.node!.isExpanded) {
        _toggleNode(selection.node!);
      } else {
        _moveSelection(
          ScrollKind.parent,
          scrollController,
          constraints.maxHeight,
        );
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // On right arrow expand the row if possible, otherwise move selection down.
      if (selection.node!.isExpandable && !selection.node!.isExpanded) {
        _toggleNode(selection.node!);
      } else {
        _moveSelection(
          ScrollKind.down,
          scrollController,
          constraints.maxHeight,
        );
      }
    }

    return KeyEventResult.handled;
  }

  void _moveSelection(
    ScrollKind scrollKind,
    ScrollController scrollController,
    double viewportHeight,
  ) {
    // get the index of the first item fully visible in the viewport
    final firstItemIndex = (scrollController.offset / defaultRowHeight).ceil();

    // '-2' in the following calculations is needed because the header row
    // occupies space in the viewport so we must subtract 1 for that, and we
    // subtract 1 to account for the fact that a partial row could be displayed
    // at the top and bottom of the view.
    final minCompleteItemsInView =
        max((viewportHeight / defaultRowHeight).floor() - 2, 0);
    final lastItemIndex = firstItemIndex + minCompleteItemsInView - 1;
    late int newSelectedNodeIndex;

    final selectionValue = widget.selectionNotifier.value;
    final selectedNodeIndex = selectionValue.nodeIndex;
    switch (scrollKind) {
      case ScrollKind.down:
        newSelectedNodeIndex = min(selectedNodeIndex! + 1, _data.length - 1);
        break;
      case ScrollKind.up:
        newSelectedNodeIndex = max(selectedNodeIndex! - 1, 0);
        break;
      case ScrollKind.parent:
        newSelectedNodeIndex = selectionValue.node!.parent != null
            ? max(_data.indexOf(selectionValue.node!.parent!), 0)
            : 0;
        break;
    }

    final newSelectedNode = _data[newSelectedNodeIndex];
    final isBelowViewport = newSelectedNodeIndex > lastItemIndex;
    final isAboveViewport = newSelectedNodeIndex < firstItemIndex;

    if (isBelowViewport) {
      // Scroll so selected row is the last full item displayed in the viewport.
      // To do this we need to be showing the (minCompleteItemsInView + 1)
      // previous item  at the top.
      unawaited(
        scrollController.animateTo(
          (newSelectedNodeIndex - minCompleteItemsInView + 1) *
              defaultRowHeight,
          duration: defaultDuration,
          curve: defaultCurve,
        ),
      );
    } else if (isAboveViewport) {
      unawaited(
        scrollController.animateTo(
          newSelectedNodeIndex * defaultRowHeight,
          duration: defaultDuration,
          curve: defaultCurve,
        ),
      );
    }

    // We do not need to scroll into view here because we have manually
    // managed the scrolling in the above checks for `isBelowViewport` and
    // `isAboveViewport`.
    widget.selectionNotifier.value = Selection(
      node: newSelectedNode,
      nodeIndex: newSelectedNodeIndex,
    );
  }
}

// TODO(kenz): https://github.com/flutter/devtools/issues/1522. The table code
// needs to be refactored to support flexible column widths.
class _Table<T> extends StatefulWidget {
  const _Table({
    Key? key,
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
    this.fillerRowCount = 0,
  }) : super(key: key);

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
  final int fillerRowCount;

  @override
  _TableState<T> createState() => _TableState<T>();
}

class _TableState<T> extends State<_Table<T>> with AutoDisposeMixin {
  late LinkedScrollControllerGroup _linkedHorizontalScrollControllerGroup;
  late ScrollController scrollController;
  late ScrollController pinnedScrollController;

  late List<T> _data;

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
  }

  @override
  void didUpdateWidget(covariant _Table<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final notifiersChanged = widget.tableController.tableData !=
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

  /// The width of all columns in the table, with additional padding.
  double get tableWidth {
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

  Widget _buildItem(BuildContext context, int index, {bool isPinned = false}) {
    return widget.rowBuilder(
      context: context,
      linkedScrollControllerGroup: _linkedHorizontalScrollControllerGroup,
      index: index,
      columnWidths: widget.columnWidths,
      isPinned: isPinned,
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
    final tableUiState = widget.tableController.tableUiState;
    final sortColumn =
        widget.tableController.columns[tableUiState.sortColumnIndex];
    if (widget.preserveVerticalScrollPosition && scrollController.hasClients) {
      scrollController.jumpTo(tableUiState.scrollOffset);
    }

    // TODO(kenz): add horizontal scrollbar.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: max(
            constraints.widthConstraints().maxWidth,
            tableWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (columnGroups != null &&
                  columnGroups.isNotEmpty &&
                  includeColumnGroupHeaders)
                TableRow<T>.tableColumnGroupHeader(
                  linkedScrollControllerGroup:
                      _linkedHorizontalScrollControllerGroup,
                  columnGroups: columnGroups,
                  columnWidths: widget.columnWidths,
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
                columnWidths: widget.columnWidths,
                sortColumn: sortColumn,
                sortDirection: tableUiState.sortDirection,
                secondarySortColumn: widget.tableController.secondarySortColumn,
                onSortChanged: widget.tableController.sortDataAndNotify,
                tall: widget.tallHeaders,
                backgroundColor: widget.headerColor,
              ),
              if (pinnedData.isNotEmpty) ...[
                SizedBox(
                  height: min(
                    widget.rowItemExtent! * pinnedData.length,
                    constraints.maxHeight / 2,
                  ),
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
                      onKey: (_, event) => widget.handleKeyEvent != null
                          ? widget.handleKeyEvent!(
                              event,
                              scrollController,
                              constraints,
                            )
                          : KeyEventResult.ignored,
                      focusNode: widget.focusNode,
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _data.length + widget.fillerRowCount,
                        itemExtent: widget.rowItemExtent,
                        itemBuilder: _buildItem,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// If a [ColumnData] implements this interface, it can override how that cell
/// is rendered.
abstract class ColumnRenderer<T> {
  /// Render the given [data] to a [Widget].
  ///
  /// This method can return `null` to indicate that the default rendering
  /// should be used instead.
  Widget? build(
    BuildContext context,
    T data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  });
}

/// If a [ColumnData] implements this interface, it can override how that column
/// header is rendered.
abstract class ColumnHeaderRenderer<T> {
  /// Render the column header to a [Widget].
  ///
  /// This method can return `null` to indicate that the default rendering
  /// should be used instead.
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  );
}

/// Presents a [node] as a row in a table.
///
/// When the given [node] is null, this widget will instead present
/// column headings.
@visibleForTesting
class TableRow<T> extends StatefulWidget {
  /// Constructs a [TableRow] that presents the column values for
  /// [node].
  const TableRow({
    Key? key,
    required this.linkedScrollControllerGroup,
    required this.node,
    required this.columns,
    required this.columnWidths,
    required this.onPressed,
    this.columnGroups,
    this.backgroundColor,
    this.expandableColumn,
    this.isExpanded = false,
    this.isExpandable = false,
    this.isSelected = false,
    this.isShown = true,
    this.displayTreeGuidelines = false,
    this.searchMatchesNotifier,
    this.activeSearchMatchNotifier,
  })  : sortColumn = null,
        sortDirection = null,
        secondarySortColumn = null,
        onSortChanged = null,
        _rowType = _TableRowType.data,
        tall = false,
        super(key: key);

  /// Constructs a [TableRow] that is empty
  const TableRow.filler({
    Key? key,
    required this.linkedScrollControllerGroup,
    required this.columns,
    required this.columnWidths,
    this.columnGroups,
    this.backgroundColor,
  })  : node = null,
        isExpanded = false,
        isExpandable = false,
        isSelected = false,
        onPressed = null,
        expandableColumn = null,
        isShown = true,
        sortColumn = null,
        sortDirection = null,
        secondarySortColumn = null,
        onSortChanged = null,
        searchMatchesNotifier = null,
        activeSearchMatchNotifier = null,
        tall = false,
        displayTreeGuidelines = false,
        _rowType = _TableRowType.filler,
        super(key: key);

  /// Constructs a [TableRow] that presents the column titles instead
  /// of any [node].
  const TableRow.tableColumnHeader({
    Key? key,
    required this.linkedScrollControllerGroup,
    required this.columns,
    required this.columnWidths,
    required this.columnGroups,
    required this.sortColumn,
    required this.sortDirection,
    required this.onSortChanged,
    this.secondarySortColumn,
    this.onPressed,
    this.tall = false,
    this.backgroundColor,
  })  : node = null,
        isExpanded = false,
        isExpandable = false,
        isSelected = false,
        expandableColumn = null,
        isShown = true,
        searchMatchesNotifier = null,
        activeSearchMatchNotifier = null,
        displayTreeGuidelines = false,
        _rowType = _TableRowType.columnHeader,
        super(key: key);

  /// Constructs a [TableRow] that presents column group titles instead of any
  /// [node].
  const TableRow.tableColumnGroupHeader({
    Key? key,
    required this.linkedScrollControllerGroup,
    required this.columnGroups,
    required this.columnWidths,
    required this.sortColumn,
    required this.sortDirection,
    required this.onSortChanged,
    this.secondarySortColumn,
    this.onPressed,
    this.tall = false,
    this.backgroundColor,
  })  : node = null,
        isExpanded = false,
        isExpandable = false,
        isSelected = false,
        expandableColumn = null,
        columns = const [],
        isShown = true,
        searchMatchesNotifier = null,
        activeSearchMatchNotifier = null,
        displayTreeGuidelines = false,
        _rowType = _TableRowType.columnGroupHeader,
        super(key: key);

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final T? node;

  final List<ColumnData<T>> columns;

  final List<ColumnGroup>? columnGroups;

  final ItemSelectedCallback<T>? onPressed;

  final List<double> columnWidths;

  final bool isSelected;

  final _TableRowType _rowType;

  final bool tall;

  /// Which column, if any, should show expansion affordances
  /// and nested rows.
  final ColumnData<T>? expandableColumn;

  /// Whether or not this row is expanded.
  ///
  /// This dictates the orientation of the expansion arrow
  /// that is drawn in the [expandableColumn].
  ///
  /// Only meaningful if [isExpanded] is true.
  final bool isExpanded;

  /// Whether or not this row can be expanded.
  ///
  /// This dictates whether an expansion arrow is
  /// drawn in the [expandableColumn].
  final bool isExpandable;

  /// Whether or not this row is shown.
  ///
  /// When the value is toggled, this row will appear or disappear.
  final bool isShown;

  /// The background color of the row.
  ///
  /// If null, defaults to `Theme.of(context).canvasColor`.
  final Color? backgroundColor;

  final ColumnData<T>? sortColumn;

  final SortDirection? sortDirection;

  final ColumnData<T>? secondarySortColumn;

  final Function(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  })? onSortChanged;

  final ValueListenable<List<T>>? searchMatchesNotifier;

  final ValueListenable<T?>? activeSearchMatchNotifier;

  final bool displayTreeGuidelines;

  @override
  State<TableRow<T>> createState() => _TableRowState<T>();
}

class _TableRowState<T> extends State<TableRow<T>>
    with
        TickerProviderStateMixin,
        CollapsibleAnimationMixin,
        AutoDisposeMixin,
        SearchableMixin {
  Key? contentKey;

  late ScrollController scrollController;

  bool isSearchMatch = false;

  bool isActiveSearchMatch = false;

  @override
  void initState() {
    super.initState();
    contentKey = ValueKey(this);
    scrollController = widget.linkedScrollControllerGroup.addAndGet();
    _initSearchListeners();
  }

  @override
  void didUpdateWidget(TableRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    setExpanded(widget.isExpanded);
    if (oldWidget.linkedScrollControllerGroup !=
        widget.linkedScrollControllerGroup) {
      scrollController.dispose();
      scrollController = widget.linkedScrollControllerGroup.addAndGet();
    }

    cancelListeners();
    _initSearchListeners();
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final widgetOnPressed = widget.onPressed;

    Function()? onPressed;
    if (node != null && widgetOnPressed != null) {
      onPressed = () => widgetOnPressed(node);
    }

    final row = tableRowFor(
      context,
      onPressed: onPressed,
    );

    final box = SizedBox(
      height: widget._rowType == _TableRowType.data
          ? defaultRowHeight
          : areaPaneHeaderHeight +
              (widget.tall ? scaleByFontFactor(densePadding) : 0.0),
      child: Material(
        color: _searchAwareBackgroundColor(),
        child: onPressed != null
            ? InkWell(
                canRequestFocus: false,
                key: contentKey,
                onTap: onPressed,
                child: row,
              )
            : row,
      ),
    );
    return box;
  }

  void _initSearchListeners() {
    if (widget.searchMatchesNotifier != null) {
      searchMatches = widget.searchMatchesNotifier!.value;
      isSearchMatch = searchMatches.contains(widget.node);
      addAutoDisposeListener(widget.searchMatchesNotifier, () {
        final isPreviousMatch = searchMatches.contains(widget.node);
        searchMatches = widget.searchMatchesNotifier!.value;
        final isNewMatch = searchMatches.contains(widget.node);

        // We only want to rebuild the row if it the match status has changed.
        if (isPreviousMatch != isNewMatch) {
          setState(() {
            isSearchMatch = isNewMatch;
          });
        }
      });
    }

    if (widget.activeSearchMatchNotifier != null) {
      activeSearchMatch = widget.activeSearchMatchNotifier!.value;
      isActiveSearchMatch = activeSearchMatch == widget.node;
      addAutoDisposeListener(widget.activeSearchMatchNotifier, () {
        final isPreviousActiveSearchMatch = activeSearchMatch == widget.node;
        activeSearchMatch = widget.activeSearchMatchNotifier!.value;
        final isNewActiveSearchMatch = activeSearchMatch == widget.node;

        // We only want to rebuild the row if it the match status has changed.
        if (isPreviousActiveSearchMatch != isNewActiveSearchMatch) {
          setState(() {
            isActiveSearchMatch = isNewActiveSearchMatch;
          });
        }
      });
    }
  }

  Color _searchAwareBackgroundColor() {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = widget.backgroundColor ?? colorScheme.surface;
    if (widget.isSelected) {
      return colorScheme.selectedRowBackgroundColor;
    }
    final searchAwareBackgroundColor = isSearchMatch
        ? Color.alphaBlend(
            isActiveSearchMatch
                ? activeSearchMatchColorOpaque
                : searchMatchColorOpaque,
            backgroundColor,
          )
        : backgroundColor;
    return searchAwareBackgroundColor;
  }

  Alignment _alignmentFor(ColumnData<T> column) {
    switch (column.alignment) {
      case ColumnAlignment.center:
        return Alignment.center;
      case ColumnAlignment.right:
        return Alignment.centerRight;
      case ColumnAlignment.left:
      default:
        return Alignment.centerLeft;
    }
  }

  /// Presents the content of this row.
  Widget tableRowFor(BuildContext context, {VoidCallback? onPressed}) {
    Widget columnFor(ColumnData<T> column, double columnWidth) {
      Widget? content;
      final theme = Theme.of(context);
      final node = widget.node;
      if (widget._rowType == _TableRowType.filler) {
        content = const SizedBox.shrink();
      } else if (widget._rowType == _TableRowType.columnHeader) {
        Widget defaultHeaderRenderer() => _ColumnHeader(
              column: column,
              isSortColumn: column == widget.sortColumn,
              secondarySortColumn: widget.secondarySortColumn,
              sortDirection: widget.sortDirection!,
              onSortChanged: widget.onSortChanged,
            );

        // ignore: avoid-unrelated-type-assertions, false positive.
        if (column is ColumnHeaderRenderer) {
          content = (column as ColumnHeaderRenderer)
              .buildHeader(context, defaultHeaderRenderer);
        }
        // If ColumnHeaderRenderer.build returns null, fall back to the default
        // rendering.
        content ??= defaultHeaderRenderer();
      } else if (node != null) {
        // TODO(kenz): clean up and pull all this code into _ColumnDataRow
        // widget class.
        final padding = column.getNodeIndentPx(node);
        assert(padding >= 0);
        // ignore: avoid-unrelated-type-assertions, false positive.
        if (column is ColumnRenderer) {
          content = (column as ColumnRenderer).build(
            context,
            node,
            isRowSelected: widget.isSelected,
            onPressed: onPressed,
          );
        }
        // If ColumnRenderer.build returns null, fall back to the default
        // rendering.
        content ??= RichText(
          text: TextSpan(
            text: column.getDisplayValue(node),
            children: [
              if (column.getCaption(node) != null)
                TextSpan(
                  text: ' ${column.getCaption(node)}',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
            style: column.contentTextStyle(
              context,
              node,
              isSelected: widget.isSelected,
            ),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: column.contentTextAlignment,
        );

        final tooltip = column.getTooltip(node);
        final richTooltip = column.getRichTooltip(node, context);
        if (tooltip.isNotEmpty || richTooltip != null) {
          content = DevToolsTooltip(
            message: richTooltip == null ? tooltip : null,
            richMessage: richTooltip,
            waitDuration: tooltipWaitLong,
            child: content,
          );
        }

        if (column == widget.expandableColumn) {
          final expandIndicator = widget.isExpandable
              ? ValueListenableBuilder(
                  valueListenable: expandController,
                  builder: (context, _, __) {
                    return RotationTransition(
                      turns: expandArrowAnimation,
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.onSurface,
                        size: defaultIconSize,
                      ),
                    );
                  },
                )
              : SizedBox(width: defaultIconSize, height: defaultIconSize);
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              expandIndicator,
              Expanded(child: content),
            ],
          );
        }
        content = Padding(
          padding: EdgeInsets.only(left: padding),
          child: ClipRect(
            child: content,
          ),
        );
      } else {
        throw Exception(
          'Expected a non-null node for this table column, but node == null.',
        );
      }

      content = SizedBox(
        width: columnWidth,
        child: Align(
          alignment: _alignmentFor(column),
          child: content,
        ),
      );
      if (widget.displayTreeGuidelines &&
          node != null &&
          node is TreeNode &&
          column is TreeColumnData) {
        content = CustomPaint(
          painter: _RowGuidelinePainter(
            node.level,
            theme.colorScheme,
          ),
          child: content,
        );
      }
      return content;
    }

    if (widget._rowType == _TableRowType.columnGroupHeader) {
      final groups = widget.columnGroups!;
      return _ColumnGroupHeaderRow(
        groups: groups,
        columnWidths: widget.columnWidths,
        scrollController: scrollController,
      );
    }

    final rowDisplayParts = <_TableRowPartDisplayType>[];
    final groups = widget.columnGroups;
    if (groups != null && groups.isNotEmpty) {
      for (int i = 0; i < groups.length; i++) {
        final groupParts = List.generate(
          groups[i].range.size as int,
          (index) => _TableRowPartDisplayType.column,
        ).joinWith(_TableRowPartDisplayType.columnSpacer);
        rowDisplayParts.addAll(groupParts);
        if (i < groups.length - 1) {
          rowDisplayParts.add(_TableRowPartDisplayType.columnGroupSpacer);
        }
      }
    } else {
      final parts = List.generate(
        widget.columns.length,
        (_) => _TableRowPartDisplayType.column,
      ).joinWith(_TableRowPartDisplayType.columnSpacer);
      rowDisplayParts.addAll(parts);
    }

    // Maps the indices from [rowDisplayParts] to the corresponding index of
    // each column in [widget.columns].
    final columnIndexMap = <int, int>{};
    // Add scope to guarantee [columnIndexTracker] is not used outside of this
    // block.
    {
      var columnIndexTracker = 0;
      for (int i = 0; i < rowDisplayParts.length; i++) {
        final type = rowDisplayParts[i];
        if (type == _TableRowPartDisplayType.column) {
          columnIndexMap[i] = columnIndexTracker;
          columnIndexTracker++;
        }
      }
    }

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        itemCount: widget.columns.length + widget.columns.numSpacers,
        itemBuilder: (context, int i) {
          final displayTypeForIndex = rowDisplayParts[i];
          switch (displayTypeForIndex) {
            case _TableRowPartDisplayType.column:
              final index = columnIndexMap[i]!;
              return columnFor(
                widget.columns[index],
                widget.columnWidths[index],
              );
            case _TableRowPartDisplayType.columnSpacer:
              return const SizedBox(
                width: columnSpacing,
                child: VerticalDivider(width: columnSpacing),
              );
            case _TableRowPartDisplayType.columnGroupSpacer:
              return const _ColumnGroupSpacer();
          }
        },
      ),
    );
    if (widget._rowType == _TableRowType.columnHeader) {
      return OutlineDecoration.onlyBottom(child: rowContent);
    }
    return rowContent;
  }

  @override
  bool get isExpanded => widget.isExpanded;

  @override
  void onExpandChanged(bool expanded) {}

  @override
  bool shouldShow() => widget.isShown;
}

class _RowGuidelinePainter extends CustomPainter {
  _RowGuidelinePainter(this.level, this.colorScheme);

  static const _treeGuidelineColors = [
    Color(0xFF13B9FD),
    Color(0xFF5BC43B),
  ];

  final int level;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < level; ++i) {
      final currentX = i * TreeColumnData.treeToggleWidth + defaultIconSize / 2;
      // Draw a vertical line for each tick identifying a connection between
      // an ancestor of this node and some other node in the tree.
      canvas.drawLine(
        Offset(currentX, 0.0),
        Offset(currentX, defaultRowHeight),
        Paint()
          ..color = _treeGuidelineColors[i % _treeGuidelineColors.length]
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is _RowGuidelinePainter) {
      return oldDelegate.colorScheme.isLight != colorScheme.isLight;
    }
    return true;
  }
}

class _ColumnHeader<T> extends StatelessWidget {
  const _ColumnHeader({
    Key? key,
    required this.column,
    required this.isSortColumn,
    required this.sortDirection,
    required this.onSortChanged,
    this.secondarySortColumn,
  }) : super(key: key);

  final ColumnData<T> column;

  final ColumnData<T>? secondarySortColumn;

  final bool isSortColumn;

  final SortDirection sortDirection;

  final Function(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  })? onSortChanged;

  @override
  Widget build(BuildContext context) {
    late Widget content;
    final title = Text(
      column.title,
      overflow: TextOverflow.ellipsis,
      textAlign: column.headerAlignment,
    );

    final headerContent = Row(
      mainAxisAlignment: column.mainAxisAlignment,
      children: [
        if (isSortColumn && column.supportsSorting) ...[
          Icon(
            sortDirection == SortDirection.ascending
                ? Icons.expand_less
                : Icons.expand_more,
            size: defaultIconSize,
          ),
          const SizedBox(width: densePadding),
        ],
        Expanded(
          child: column.titleTooltip != null
              ? DevToolsTooltip(
                  message: column.titleTooltip,
                  padding: const EdgeInsets.all(denseSpacing),
                  child: title,
                )
              : title,
        ),
      ],
    );

    content = column.includeHeader
        ? InkWell(
            canRequestFocus: false,
            onTap: column.supportsSorting
                ? () => _handleSortChange(
                      column,
                      secondarySortColumn: secondarySortColumn,
                    )
                : null,
            child: headerContent,
          )
        : headerContent;
    return content;
  }

  void _handleSortChange(
    ColumnData<T> columnData, {
    ColumnData<T>? secondarySortColumn,
  }) {
    SortDirection direction;
    if (isSortColumn) {
      direction = sortDirection.reverse();
    } else if (columnData.numeric) {
      direction = SortDirection.descending;
    } else {
      direction = SortDirection.ascending;
    }
    onSortChanged?.call(
      columnData,
      direction,
      secondarySortColumn: secondarySortColumn,
    );
  }
}

class _ColumnGroupHeaderRow extends StatelessWidget {
  const _ColumnGroupHeaderRow({
    required this.groups,
    required this.columnWidths,
    required this.scrollController,
    Key? key,
  }) : super(key: key);

  final List<ColumnGroup> groups;

  final List<double> columnWidths;

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      decoration: BoxDecoration(
        border: Border(
          bottom: defaultBorderSide(Theme.of(context)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        itemCount: groups.length + groups.numSpacers,
        itemBuilder: (context, int i) {
          if (i % 2 == 1) {
            return const _ColumnGroupSpacer();
          }

          final group = groups[i ~/ 2];
          final groupRange = group.range;
          double groupWidth = 0.0;
          for (int j = groupRange.begin as int; j < groupRange.end; j++) {
            final columnWidth = columnWidths[j];
            groupWidth += columnWidth;
            if (j < groupRange.end - 1) {
              groupWidth += columnSpacing;
            }
          }
          return Container(
            alignment: Alignment.center,
            width: groupWidth,
            child: group.title,
          );
        },
      ),
    );
  }
}

class _ColumnGroupSpacer extends StatelessWidget {
  const _ColumnGroupSpacer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: (columnGroupSpacingWithPadding - columnGroupSpacing) / 2,
      ),
      child: Container(
        width: columnGroupSpacing,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black,
              Theme.of(context).focusColor,
              Colors.black,
            ],
          ),
        ),
      ),
    );
  }
}

enum _TableRowType {
  data,
  columnHeader,
  columnGroupHeader,
  filler,
}

enum _TableRowPartDisplayType {
  column,
  columnSpacer,
  columnGroupSpacer,
}
