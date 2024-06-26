// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'table.dart';

enum TreeTableScrollKind {
  up,
  down,
  parent,
}

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
    super.key,
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
        assert(columns.contains(defaultSortColumn));

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
    return DevToolsTable<T>(
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
    required bool enableHoverHandling,
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
    KeyEvent event,
    ScrollController scrollController,
    BoxConstraints constraints,
  ) {
    if (!event.isKeyDownOrRepeat) return KeyEventResult.ignored;

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
      _moveSelection(
        TreeTableScrollKind.down,
        scrollController,
        constraints.maxHeight,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(
        TreeTableScrollKind.up,
        scrollController,
        constraints.maxHeight,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // On left arrow collapse the row if it is expanded. If it is not, move
      // selection to its parent.
      if (selection.node!.isExpanded) {
        _toggleNode(selection.node!);
      } else {
        _moveSelection(
          TreeTableScrollKind.parent,
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
          TreeTableScrollKind.down,
          scrollController,
          constraints.maxHeight,
        );
      }
    }

    return KeyEventResult.handled;
  }

  void _moveSelection(
    TreeTableScrollKind scrollKind,
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
      case TreeTableScrollKind.down:
        newSelectedNodeIndex = min(selectedNodeIndex! + 1, _data.length - 1);
        break;
      case TreeTableScrollKind.up:
        newSelectedNodeIndex = max(selectedNodeIndex! - 1, 0);
        break;
      case TreeTableScrollKind.parent:
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

/// A custom painter to draw guidelines between tree table nodes.
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
