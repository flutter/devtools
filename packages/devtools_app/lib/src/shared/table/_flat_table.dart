// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'table.dart';

/// A [FlatTable] widget that is searchable.
///
/// The table requires a [searchController], which is responsible for feeding
/// information about search matches and the active search match to the table.
///
/// This table will automatically refresh search matches on the
/// [searchController] after sort operations that are triggered from the table.
class SearchableFlatTable<T extends SearchableDataMixin> extends FlatTable<T> {
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
    super.key,
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
    this.fillWithEmptyRows = false,
    this.enableHoverHandling = false,
    ValueNotifier<T?>? selectionNotifier,
  }) : selectionNotifier = selectionNotifier ?? ValueNotifier<T?>(null);

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

  /// Whether to fill the table with empty rows.
  final bool fillWithEmptyRows;

  /// Whether to enable hover handling.
  final bool enableHoverHandling;

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
  /// Defaults to [FlatTablePinBehavior.none], which disables pinning.
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
          oldWidget.columns.map((c) => c.config),
          newWidget.columns.map((c) => c.config),
        ) ||
        !collectionEquals(
          oldWidget.columnGroups?.map((c) => c.title),
          newWidget.columnGroups?.map((c) => c.title),
        );
    return columnsChanged;
  }

  @override
  Widget build(BuildContext context) {
    Widget buildTable(List<double> columnWidths) => DevToolsTable<T>(
          tableController: tableController,
          columnWidths: columnWidths,
          autoScrollContent: widget.autoScrollContent,
          rowBuilder: _buildRow,
          activeSearchMatchNotifier: widget.activeSearchMatchNotifier,
          rowItemExtent: defaultRowHeight,
          preserveVerticalScrollPosition: widget.preserveVerticalScrollPosition,
          tallHeaders: widget.tallHeaders,
          headerColor: widget.headerColor,
          fillWithEmptyRows: widget.fillWithEmptyRows,
          enableHoverHandling: widget.enableHoverHandling,
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
    required bool enableHoverHandling,
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
          enableHoverHandling: enableHoverHandling,
        );
      },
    );
  }
}
