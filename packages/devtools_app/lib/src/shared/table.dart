// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter/services.dart';

import '../primitives/auto_dispose_mixin.dart';
import '../primitives/flutter_widgets/linked_scroll_controller.dart';
import '../primitives/listenable.dart';
import '../primitives/trees.dart';
import '../primitives/utils.dart';
import '../ui/colors.dart';
import '../ui/search.dart';
import '../ui/utils.dart';
import 'collapsible_mixin.dart';
import 'common_widgets.dart';
import 'table_data.dart';
import 'theme.dart';
import 'tree.dart';
import 'utils.dart';

// TODO(devoncarew): We need to render the selected row with a different
// background color.

/// The maximum height to allow for rows in the table.
///
/// When rows in the table expand or collapse, they will animate between a
/// height of 0 and a height of [defaultRowHeight].
double get defaultRowHeight => scaleByFontFactor(32.0);

const _columnGroupSpacing = 4.0;
const _columnGroupSpacingWithPadding = _columnGroupSpacing + 2 * defaultSpacing;
const _columnSpacing = defaultSpacing;

typedef IndexedScrollableWidgetBuilder = Widget Function(
  BuildContext,
  LinkedScrollControllerGroup linkedScrollControllerGroup,
  int index,
  List<double> columnWidths,
);

typedef TableKeyEventHandler = KeyEventResult Function(
  RawKeyEvent event,
  ScrollController scrollController,
  BoxConstraints constraints,
);

enum ScrollKind { up, down, parent }

/// A table that displays in a collection of [data], based on a collection of
/// [ColumnData].
///
/// The [ColumnData] gives this table information about how to size its columns,
/// and how to present each row of `data`.
class FlatTable<T> extends StatefulWidget {
  const FlatTable({
    Key? key,
    required this.columns,
    this.columnGroups,
    required this.data,
    this.autoScrollContent = false,
    required this.keyFactory,
    required this.onItemSelected,
    required this.sortColumn,
    required this.sortDirection,
    this.secondarySortColumn,
    this.onSortChanged,
    this.searchMatchesNotifier,
    this.activeSearchMatchNotifier,
    this.selectionNotifier,
  }) : super(key: key);

  final List<ColumnData<T>> columns;

  final List<ColumnGroup>? columnGroups;

  final List<T> data;

  /// Auto-scrolling the table to keep new content visible.
  final bool autoScrollContent;

  /// Factory that creates keys for each row in this table.
  final Key Function(T data) keyFactory;

  final ItemCallback<T> onItemSelected;

  final ColumnData<T> sortColumn;

  final SortDirection sortDirection;

  final ColumnData<T>? secondarySortColumn;

  final Function(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  })? onSortChanged;

  final ValueListenable<List<T>>? searchMatchesNotifier;

  final ValueListenable<T?>? activeSearchMatchNotifier;

  final ValueListenable<T?>? selectionNotifier;

  @override
  FlatTableState<T> createState() => FlatTableState<T>();
}

class FlatTableState<T> extends State<FlatTable<T>>
    implements SortableTable<T> {
  late List<T> data;

  @override
  void initState() {
    super.initState();

    _initData();
  }

  @override
  void didUpdateWidget(FlatTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sortColumn != oldWidget.sortColumn ||
        widget.sortDirection != oldWidget.sortDirection ||
        !collectionEquals(widget.data, oldWidget.data)) {
      _initData();
    }
  }

  void _initData() {
    data = List.from(widget.data);
    sortData(
      widget.sortColumn,
      widget.sortDirection,
      secondarySortColumn: widget.secondarySortColumn,
    );
  }

  @visibleForTesting
  List<double> computeColumnWidths(double maxWidth) {
    // Subtract width from outer padding around table.
    maxWidth -= 2 * defaultSpacing;
    final numColumnGroupSpacers = widget.columnGroups?.numSpacers ?? 0;
    final numColumnSpacers = widget.columns.numSpacers - numColumnGroupSpacers;
    maxWidth -= numColumnSpacers * _columnSpacing;
    maxWidth -= numColumnGroupSpacers * _columnGroupSpacingWithPadding;
    maxWidth = max(0, maxWidth);
    double available = maxWidth;
    // Columns sorted by increasing minWidth.
    final List<ColumnData<T>> sortedColumns = widget.columns.toList()
      ..sort((a, b) {
        if (a.minWidthPx != null && b.minWidthPx != null) {
          return a.minWidthPx!.compareTo(b.minWidthPx!);
        }
        if (a.minWidthPx != null) return -1;
        if (b.minWidthPx != null) return 1;
        return 0;
      });

    for (var col in widget.columns) {
      if (col.fixedWidthPx != null) {
        available -= col.fixedWidthPx!;
      } else if (col.minWidthPx != null) {
        available -= col.minWidthPx!;
      }
    }
    available = max(available, 0);
    int unconstrainedCount = 0;
    for (var column in sortedColumns) {
      if (column.fixedWidthPx == null && column.minWidthPx == null) {
        unconstrainedCount++;
      }
    }

    if (available > 0) {
      // We need to find how many columns with minWidth constraints can actually
      // be treated as unconstrained as their minWidth constraint is satisfied
      // by the width given to all unconstrained columns.
      // We use a greedy algorithm to accurately compute this by iterating
      // through the columns from the smallest minWidth to largest minWidth
      // incrementally adding columns where the minWidth constraint can be
      // satisfied using the width given to unconstrained columns.
      for (var column in sortedColumns) {
        if (column.fixedWidthPx == null && column.minWidthPx != null) {
          // Width of this column if it was not clamped to its min width.
          // We add column.minWidthPx to the available width because
          // available is currently not considering the space reserved for this
          // column's min width as available.
          final widthIfUnconstrainedByMinWidth =
              (available + column.minWidthPx!) / (unconstrainedCount + 1);
          if (widthIfUnconstrainedByMinWidth < column.minWidthPx!) {
            // We have found the first column that will have to be clamped to
            // its min width.
            break;
          }
          // As this column's width in the final layout is greater than its
          // min width, we can treat it as unconstrained and give its min width
          // back to the available pool.
          unconstrainedCount++;
          available += column.minWidthPx!;
        }
      }
    }
    final unconstrainedWidth =
        unconstrainedCount > 0 ? available / unconstrainedCount : available;
    int unconstrainedFound = 0;
    final widths = <double>[];
    for (ColumnData<T> column in widget.columns) {
      double? width = column.fixedWidthPx;
      if (width == null) {
        if (column.minWidthPx != null &&
            column.minWidthPx! > unconstrainedWidth) {
          width = column.minWidthPx!;
        } else {
          width = unconstrainedWidth;
          unconstrainedFound++;
        }
      }
      widths.add(width);
    }
    assert(unconstrainedCount == unconstrainedFound);
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidths = computeColumnWidths(constraints.maxWidth);

        return _Table<T>(
          data: data,
          columns: widget.columns,
          columnGroups: widget.columnGroups,
          columnWidths: columnWidths,
          autoScrollContent: widget.autoScrollContent,
          rowBuilder: _buildRow,
          sortColumn: widget.sortColumn,
          sortDirection: widget.sortDirection,
          secondarySortColumn: widget.secondarySortColumn,
          onSortChanged: _sortDataAndUpdate,
          activeSearchMatchNotifier: widget.activeSearchMatchNotifier,
          rowItemExtent: defaultRowHeight,
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    LinkedScrollControllerGroup linkedScrollControllerGroup,
    int index,
    List<double> columnWidths,
  ) {
    final node = data[index];

    final selectionNotifier =
        widget.selectionNotifier ?? FixedValueListenable<T?>(null);
    return ValueListenableBuilder<T?>(
      valueListenable: selectionNotifier,
      builder: (context, selected, _) {
        return TableRow<T>(
          key: widget.keyFactory(node),
          linkedScrollControllerGroup: linkedScrollControllerGroup,
          node: node,
          onPressed: widget.onItemSelected,
          columns: widget.columns,
          columnGroups: widget.columnGroups,
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

  void _sortDataAndUpdate(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  }) {
    setState(() {
      sortData(column, direction, secondarySortColumn: secondarySortColumn);
      if (widget.onSortChanged != null) {
        widget.onSortChanged!(
          column,
          direction,
          secondarySortColumn: secondarySortColumn,
        );
      }
    });
  }

  @override
  void sortData(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  }) {
    data.sort(
      (T a, T b) => _compareData<T>(
        a,
        b,
        column,
        direction,
        secondarySortColumn: secondarySortColumn,
      ),
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
  final int Function(T)? nodeIndexCalculator;
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
    required this.columns,
    required this.treeColumn,
    required this.dataRoots,
    required this.keyFactory,
    required this.sortColumn,
    required this.sortDirection,
    this.secondarySortColumn,
    this.selectionNotifier,
    this.autoExpandRoots = false,
  })  : assert(columns.contains(treeColumn)),
        assert(columns.contains(sortColumn)),
        super(key: key);

  /// The columns to show in this table.
  final List<ColumnData<T>> columns;

  /// The column of the table to treat as expandable.
  final TreeColumnData<T> treeColumn;

  /// The tree structures of rows to show in this table.
  final List<T> dataRoots;

  /// Factory that creates keys for each row in this table.
  final Key Function(T) keyFactory;

  final ColumnData<T> sortColumn;

  final SortDirection sortDirection;

  final ColumnData<T>? secondarySortColumn;

  final ValueNotifier<Selection<T>>? selectionNotifier;

  final bool autoExpandRoots;

  @override
  TreeTableState<T> createState() => TreeTableState<T>();
}

class TreeTableState<T extends TreeNode<T>> extends State<TreeTable<T>>
    with TickerProviderStateMixin, TreeMixin<T>, AutoDisposeMixin
    implements SortableTable<T> {
  /// The number of items to show when animating out the tree table.
  static const itemsToShowWhenAnimating = 50;
  List<T> animatingChildren = [];
  Set<T> animatingChildrenSet = {};
  T? animatingNode;
  late List<double> columnWidths;
  late List<bool> rootsExpanded;
  late FocusNode _focusNode;

  late ValueNotifier<Selection<T>> selectionNotifier;

  FocusNode? get focusNode => _focusNode;

  @override
  void initState() {
    super.initState();
    _initData();

    addAutoDisposeListener(selectionNotifier, () {
      setState(() {
        final node = selectionNotifier.value.node;
        if (node != null) {
          expandParents(node.parent);
        }
      });
    });

    rootsExpanded =
        List.generate(dataRoots.length, (index) => dataRoots[index].isExpanded);
    _updateItems();
    _focusNode = FocusNode(debugLabel: 'table');
    autoDisposeFocusNode(_focusNode);
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

  @override
  void didUpdateWidget(TreeTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget == oldWidget) return;

    if (widget.sortColumn != oldWidget.sortColumn ||
        widget.sortDirection != oldWidget.sortDirection ||
        !collectionEquals(widget.dataRoots, oldWidget.dataRoots)) {
      _initData();
    }
    rootsExpanded =
        List.generate(dataRoots.length, (index) => dataRoots[index].isExpanded);
    _updateItems();
  }

  void _initData() {
    dataRoots = List.generate(widget.dataRoots.length, (index) {
      final root = widget.dataRoots[index];
      if (widget.autoExpandRoots) {
        root.expand();
      }
      return root;
    });
    dataRoots = List.from(widget.dataRoots);
    sortData(
      widget.sortColumn,
      widget.sortDirection,
      secondarySortColumn: widget.secondarySortColumn,
    );

    selectionNotifier = widget.selectionNotifier ??
        ValueNotifier<Selection<T>>(Selection.empty());
  }

  void _updateItems() {
    setState(() {
      items = buildFlatList(dataRoots);
      // Leave enough space for the animating children during the animation.
      columnWidths = _computeColumnWidths([...items, ...animatingChildren]);
    });
  }

  void _onItemsAnimated() {
    setState(() {
      animatingChildren = [];
      animatingChildrenSet = {};
      // Remove the animating children from the column width computations.
      columnWidths = _computeColumnWidths(items);
    });
  }

  void _onItemPressed(T node, int nodeIndex) {
    // Rebuilds the table whenever the tree structure has been updated.
    selectionNotifier.value = Selection(
      node: node,
      nodeIndex: nodeIndex,
    );

    _toggleNode(node);
  }

  void _toggleNode(T node) {
    if (!node.isExpandable) {
      node.leaf();
      _updateItems();
      return;
    }

    setState(() {
      if (!node.isExpandable) return;
      animatingNode = node;
      List<T> nodeChildren;
      if (node.isExpanded) {
        // Compute the children of the expanded node before collapsing.
        nodeChildren = buildFlatList([node]);
        node.collapse();
      } else {
        node.expand();
        // Compute the children of the collapsed node after expanding it.
        nodeChildren = buildFlatList([node]);
      }
      // The first item will be node itself. We will take the next few items
      // to generate a convincing expansion animation without creating
      // potentially thousands of widgets.
      animatingChildren =
          nodeChildren.skip(1).take(itemsToShowWhenAnimating).toList();
      animatingChildrenSet = Set.of(animatingChildren);

      // Update the tracked expansion of the root node if needed.
      if (dataRoots.contains(node)) {
        final rootIndex = dataRoots.indexOf(node);
        rootsExpanded[rootIndex] = node.isExpanded;
      }
    });
    _updateItems();
  }

  List<double> _computeColumnWidths(List<T> flattenedList) {
    final firstRoot = dataRoots.first;
    var deepest = firstRoot;
    // This will use the width of all rows in the table, even the rows
    // that are hidden by nesting.
    // We may want to change this to using a flattened list of only
    // the list items that should show right now.
    for (var node in flattenedList) {
      if (node.level > deepest.level) {
        deepest = node;
      }
    }
    final widths = <double>[];
    for (var column in widget.columns) {
      var width = column.getNodeIndentPx(deepest);
      assert(width >= 0.0);
      if (column.fixedWidthPx != null) {
        width += column.fixedWidthPx!;
      } else {
        // TODO(djshuckerow): measure the text of the longest content
        // to get an idea for how wide this column should be.
        // Text measurement is a somewhat expensive algorithm, so we don't
        // want to do it for every row in the table, only the row
        // we are confident is the widest.  A reasonable heuristic is the row
        // with the longest text, but because of variable-width fonts, this is
        // not always true.
        width += _Table.defaultColumnWidth;
      }
      widths.add(width);
    }
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    return _Table<T>(
      data: items,
      columns: widget.columns,
      columnWidths: columnWidths,
      rowBuilder: _buildRow,
      sortColumn: widget.sortColumn,
      secondarySortColumn: widget.secondarySortColumn,
      sortDirection: widget.sortDirection,
      onSortChanged: _sortDataAndUpdate,
      focusNode: _focusNode,
      handleKeyEvent: _handleKeyEvent,
      selectionNotifier: selectionNotifier,
    );
  }

  Widget _buildRow(
    BuildContext context,
    LinkedScrollControllerGroup linkedScrollControllerGroup,
    int index,
    List<double> columnWidths,
  ) {
    Widget rowForNode(T node) {
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
        columns: widget.columns,
        columnWidths: columnWidths,
        expandableColumn: widget.treeColumn,
        isSelected: selectionNotifier.value.node == node,
        isExpanded: node.isExpanded,
        isExpandable: node.isExpandable,
        isShown: node.shouldShow(),
        expansionChildren:
            node != animatingNode || animatingChildrenSet.contains(node)
                ? null
                : [for (var child in animatingChildren) rowForNode(child)],
        onExpansionCompleted: _onItemsAnimated,
      );
    }

    final node = items[index];
    if (animatingChildrenSet.contains(node)) return const SizedBox();
    return rowForNode(node);
  }

  @override
  void sortData(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  }) {
    final sortFunction = (T a, T b) => _compareData<T>(
          a,
          b,
          column,
          direction,
          secondarySortColumn: secondarySortColumn,
        );
    void _sort(T dataObject) {
      dataObject.children
        ..sort(sortFunction)
        ..forEach(_sort);
    }

    dataRoots
      ..sort(sortFunction)
      ..forEach(_sort);
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
      LogicalKeyboardKey.arrowRight
    ].contains(event.logicalKey)) return KeyEventResult.ignored;

    // If there is no selected node, choose the first one.
    if (selectionNotifier.value.node == null) {
      selectionNotifier.value = Selection(
        node: items[0],
        nodeIndex: 0,
      );
    }

    assert(
      selectionNotifier.value.node == items[selectionNotifier.value.nodeIndex!],
    );

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(ScrollKind.down, scrollController, constraints.maxHeight);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(ScrollKind.up, scrollController, constraints.maxHeight);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // On left arrow collapse the row if it is expanded. If it is not, move
      // selection to its parent.
      if (selectionNotifier.value.node!.isExpanded) {
        _toggleNode(selectionNotifier.value.node!);
      } else {
        _moveSelection(
          ScrollKind.parent,
          scrollController,
          constraints.maxHeight,
        );
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // On right arrow expand the row if possible, otherwise move selection down.
      if (selectionNotifier.value.node!.isExpandable &&
          !selectionNotifier.value.node!.isExpanded) {
        _toggleNode(selectionNotifier.value.node!);
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

    final selectionValue = selectionNotifier.value;
    final selectedNodeIndex = selectionValue.nodeIndex;
    switch (scrollKind) {
      case ScrollKind.down:
        newSelectedNodeIndex = min(selectedNodeIndex! + 1, items.length - 1);
        break;
      case ScrollKind.up:
        newSelectedNodeIndex = max(selectedNodeIndex! - 1, 0);
        break;
      case ScrollKind.parent:
        newSelectedNodeIndex = selectionValue.node!.parent != null
            ? max(items.indexOf(selectionValue.node!.parent!), 0)
            : 0;
        break;
    }

    final newSelectedNode = items[newSelectedNodeIndex];
    final isBelowViewport = newSelectedNodeIndex > lastItemIndex;
    final isAboveViewport = newSelectedNodeIndex < firstItemIndex;

    if (isBelowViewport) {
      // Scroll so selected row is the last full item displayed in the viewport.
      // To do this we need to be showing the (minCompleteItemsInView + 1)
      // previous item  at the top.
      scrollController.animateTo(
        (newSelectedNodeIndex - minCompleteItemsInView + 1) * defaultRowHeight,
        duration: defaultDuration,
        curve: defaultCurve,
      );
    } else if (isAboveViewport) {
      scrollController.animateTo(
        newSelectedNodeIndex * defaultRowHeight,
        duration: defaultDuration,
        curve: defaultCurve,
      );
    }

    setState(() {
      // We do not need to scroll into view here because we have manually
      // managed the scrolling in the above checks for `isBelowViewport` and
      // `isAboveViewport`.
      selectionNotifier.value = Selection(
        node: newSelectedNode,
        nodeIndex: newSelectedNodeIndex,
      );
    });
  }

  void _sortDataAndUpdate(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  }) {
    sortData(column, direction, secondarySortColumn: secondarySortColumn);
    _updateItems();
  }
}

// TODO(kenz): https://github.com/flutter/devtools/issues/1522. The table code
// needs to be refactored to support flexible column widths.
class _Table<T> extends StatefulWidget {
  const _Table({
    Key? key,
    required this.data,
    required this.columns,
    required this.columnWidths,
    required this.rowBuilder,
    required this.sortColumn,
    required this.sortDirection,
    required this.onSortChanged,
    this.columnGroups,
    this.secondarySortColumn,
    this.focusNode,
    this.handleKeyEvent,
    this.autoScrollContent = false,
    this.selectionNotifier,
    this.activeSearchMatchNotifier,
    this.rowItemExtent,
  }) : super(key: key);

  final List<T> data;

  final bool autoScrollContent;
  final List<ColumnData<T>> columns;
  final List<ColumnGroup>? columnGroups;
  final List<double> columnWidths;
  final IndexedScrollableWidgetBuilder rowBuilder;
  final ColumnData<T> sortColumn;
  final SortDirection sortDirection;
  final ColumnData<T>? secondarySortColumn;
  final double? rowItemExtent;
  final Function(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  }) onSortChanged;
  final FocusNode? focusNode;
  final TableKeyEventHandler? handleKeyEvent;
  final ValueNotifier<Selection<T>>? selectionNotifier;
  final ValueListenable<T?>? activeSearchMatchNotifier;

  /// The width to assume for columns that don't specify a width.
  static const defaultColumnWidth = 500.0;

  @override
  _TableState<T> createState() => _TableState<T>();
}

class _TableState<T> extends State<_Table<T>> with AutoDisposeMixin {
  late LinkedScrollControllerGroup _linkedHorizontalScrollControllerGroup;
  late ColumnData<T> sortColumn;
  late SortDirection sortDirection;
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();

    _linkedHorizontalScrollControllerGroup = LinkedScrollControllerGroup();
    sortColumn = widget.sortColumn;
    sortDirection = widget.sortDirection;
    scrollController = ScrollController();
    _addScrollListener(widget.selectionNotifier);
    _initSearchListener();
  }

  void _addScrollListener(ValueNotifier<Selection<T>>? selectionNotifier) {
    if (selectionNotifier != null) {
      addAutoDisposeListener(selectionNotifier, () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final Selection<T> selection = selectionNotifier.value;
          final T? node = selection.node;
          final int Function(T)? nodeIndexCalculator =
              selection.nodeIndexCalculator;
          final int? nodeIndex = selection.nodeIndex;

          if (selection.scrollIntoView && node != null) {
            final int selectedDisplayRow = nodeIndexCalculator != null
                ? nodeIndexCalculator(node)
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

    final index = widget.data.indexOf(activeSearch);

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
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  /// The width of all columns in the table, with additional padding.
  double get tableWidth {
    var tableWidth = 2 * defaultSpacing;
    final numColumnGroupSpacers = widget.columnGroups?.numSpacers ?? 0;
    final numColumnSpacers = widget.columns.numSpacers - numColumnGroupSpacers;
    tableWidth += numColumnSpacers * _columnSpacing;
    tableWidth += numColumnGroupSpacers * _columnGroupSpacingWithPadding;
    for (var columnWidth in widget.columnWidths) {
      tableWidth += columnWidth;
    }
    return tableWidth;
  }

  Widget _buildItem(BuildContext context, int index) {
    return widget.rowBuilder(
      context,
      _linkedHorizontalScrollControllerGroup,
      index,
      widget.columnWidths,
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we're at the end already, scroll to expose the new content.
    if (widget.autoScrollContent) {
      if (scrollController.hasClients && scrollController.atScrollBottom) {
        scrollController.autoScrollToBottom();
      }
    }

    final columnGroups = widget.columnGroups;

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
              if (columnGroups != null && columnGroups.isNotEmpty)
                TableRow<T>.tableColumnGroupHeader(
                  linkedScrollControllerGroup:
                      _linkedHorizontalScrollControllerGroup,
                  columnGroups: columnGroups,
                  columnWidths: widget.columnWidths,
                  sortColumn: sortColumn,
                  sortDirection: sortDirection,
                  secondarySortColumn: widget.secondarySortColumn,
                  onSortChanged: _sortData,
                ),
              TableRow<T>.tableColumnHeader(
                key: const Key('Table header'),
                linkedScrollControllerGroup:
                    _linkedHorizontalScrollControllerGroup,
                columns: widget.columns,
                columnGroups: columnGroups,
                columnWidths: widget.columnWidths,
                sortColumn: sortColumn,
                sortDirection: sortDirection,
                secondarySortColumn: widget.secondarySortColumn,
                onSortChanged: _sortData,
              ),
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
                        itemCount: widget.data.length,
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

  void _sortData(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  }) {
    sortDirection = direction;
    sortColumn = column;
    widget.onSortChanged(
      column,
      direction,
      secondarySortColumn: secondarySortColumn,
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
  Widget build(
    BuildContext context,
    T data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  });
}

/// Callback for when a specific item in a table is selected.
typedef ItemCallback<T> = void Function(T item);

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
    this.expansionChildren,
    this.onExpansionCompleted,
    this.isExpanded = false,
    this.isExpandable = false,
    this.isSelected = false,
    this.isShown = true,
    this.searchMatchesNotifier,
    this.activeSearchMatchNotifier,
  })  : sortColumn = null,
        sortDirection = null,
        secondarySortColumn = null,
        onSortChanged = null,
        rowType = _TableRowType.data,
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
  })  : node = null,
        isExpanded = false,
        isExpandable = false,
        isSelected = false,
        expandableColumn = null,
        isShown = true,
        backgroundColor = null,
        expansionChildren = null,
        onExpansionCompleted = null,
        searchMatchesNotifier = null,
        activeSearchMatchNotifier = null,
        rowType = _TableRowType.columnHeader,
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
  })  : node = null,
        isExpanded = false,
        isExpandable = false,
        isSelected = false,
        expandableColumn = null,
        columns = const [],
        isShown = true,
        backgroundColor = null,
        expansionChildren = null,
        onExpansionCompleted = null,
        searchMatchesNotifier = null,
        activeSearchMatchNotifier = null,
        rowType = _TableRowType.columnGroupHeader,
        super(key: key);

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final T? node;

  final List<ColumnData<T>> columns;

  final List<ColumnGroup>? columnGroups;

  final ItemCallback<T>? onPressed;

  final List<double> columnWidths;

  final bool isSelected;

  final _TableRowType rowType;

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
  /// When the value is toggled, this row will animate in or out.
  final bool isShown;

  /// The children to show when the expand animation of this widget is running.
  final List<Widget>? expansionChildren;
  final VoidCallback? onExpansionCompleted;

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

  @override
  _TableRowState<T> createState() => _TableRowState<T>();
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

    expandController.addStatusListener((status) {
      setState(() {});
      if ([AnimationStatus.completed, AnimationStatus.dismissed]
              .contains(status) &&
          widget.onExpansionCompleted != null) {
        widget.onExpansionCompleted!();
      }
    });

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
      height: widget.rowType == _TableRowType.data
          ? defaultRowHeight
          : areaPaneHeaderHeight,
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
    if (widget.expansionChildren == null) return box;

    return AnimatedBuilder(
      animation: expandCurve,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            box,
            for (var c in widget.expansionChildren!)
              SizedBox(
                height: defaultRowHeight * expandCurve.value,
                child: OverflowBox(
                  minHeight: 0.0,
                  maxHeight: defaultRowHeight,
                  alignment: Alignment.topCenter,
                  child: c,
                ),
              ),
          ],
        );
      },
    );
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
    final backgroundColor =
        widget.backgroundColor ?? Theme.of(context).titleSolidBackgroundColor;
    if (widget.isSelected) {
      return Theme.of(context).selectedRowColor;
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

  TextAlign _textAlignmentFor(ColumnData<T> column) {
    switch (column.alignment) {
      case ColumnAlignment.center:
        return TextAlign.center;
      case ColumnAlignment.right:
        return TextAlign.right;
      case ColumnAlignment.left:
      default:
        return TextAlign.left;
    }
  }

  MainAxisAlignment _mainAxisAlignmentFor(ColumnData<T> column) {
    switch (column.alignment) {
      case ColumnAlignment.center:
        return MainAxisAlignment.center;
      case ColumnAlignment.right:
        return MainAxisAlignment.end;
      case ColumnAlignment.left:
      default:
        return MainAxisAlignment.start;
    }
  }

  /// Presents the content of this row.
  Widget tableRowFor(BuildContext context, {VoidCallback? onPressed}) {
    Widget columnFor(ColumnData<T> column, double columnWidth) {
      late Widget content;
      final node = widget.node;
      if (widget.rowType == _TableRowType.columnHeader) {
        // TODO(kenz): clean up and pull all this code into _ColumnHeaderRow
        // widget class.
        final isSortColumn = column == widget.sortColumn;

        final title = Text(
          column.title,
          overflow: TextOverflow.ellipsis,
        );

        final headerContent = Row(
          mainAxisAlignment: _mainAxisAlignmentFor(column),
          children: [
            if (isSortColumn && column.supportsSorting) ...[
              Icon(
                widget.sortDirection == SortDirection.ascending
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: defaultIconSize,
              ),
              const SizedBox(width: densePadding),
            ],
            // TODO: This Flexible wrapper was added to get the
            // network_profiler_test.dart tests to pass.
            Flexible(
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
                          secondarySortColumn: widget.secondarySortColumn,
                        )
                    : null,
                child: headerContent,
              )
            : headerContent;
      } else if (node != null) {
        // TODO(kenz): clean up and pull all this code into _ColumnDataRow
        // widget class.
        final padding = column.getNodeIndentPx(node);
        assert(padding >= 0);

        if (column is ColumnRenderer) {
          content = (column as ColumnRenderer).build(
            context,
            node,
            isRowSelected: widget.isSelected,
            onPressed: onPressed,
          );
        } else {
          content = RichText(
            text: TextSpan(
              text: column.getDisplayValue(node),
              children: [
                if (column.getCaption(node) != null)
                  TextSpan(
                    text: ' ${column.getCaption(node)}',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                  )
              ],
              style: contentTextStyle(column),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: _textAlignmentFor(column),
          );
        }

        final tooltip = column.getTooltip(node);
        if (tooltip.isNotEmpty) {
          content = DevToolsTooltip(
            message: tooltip,
            waitDuration: tooltipWaitLong,
            child: content,
          );
        }

        if (column == widget.expandableColumn) {
          final expandIndicator = widget.isExpandable
              ? RotationTransition(
                  turns: expandArrowAnimation,
                  child: Icon(
                    Icons.expand_more,
                    color: widget.isSelected
                        ? defaultSelectionForegroundColor
                        : null,
                    size: defaultIconSize,
                  ),
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
      return content;
    }

    if (widget.rowType == _TableRowType.columnGroupHeader) {
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
        (index) => _TableRowPartDisplayType.column,
      ).joinWith(_TableRowPartDisplayType.columnSpacer);
      rowDisplayParts.addAll(parts);
    }

    var columnIndexTracker = 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        itemCount: widget.columns.length + widget.columns.numSpacers,
        itemBuilder: (context, int i) {
          final displayTypeForIndex = rowDisplayParts[i];
          switch (displayTypeForIndex) {
            case _TableRowPartDisplayType.column:
              final current = columnIndexTracker;
              columnIndexTracker++;
              return columnFor(
                widget.columns[current],
                widget.columnWidths[current],
              );
            case _TableRowPartDisplayType.columnSpacer:
              return const SizedBox(
                width: _columnSpacing,
                child: VerticalDivider(width: _columnSpacing),
              );
            case _TableRowPartDisplayType.columnGroupSpacer:
              return const _ColumnGroupSpacer();
          }
        },
      ),
    );
  }

  TextStyle contentTextStyle(ColumnData<T> column) {
    final textColor = widget.isSelected
        ? defaultSelectionForegroundColor
        : column.getTextColor(widget.node!);
    final fontStyle = Theme.of(context).fixedFontStyle;
    return textColor == null ? fontStyle : fontStyle.copyWith(color: textColor);
  }

  @override
  bool get isExpanded => widget.isExpanded;

  @override
  void onExpandChanged(bool expanded) {}

  @override
  bool shouldShow() => widget.isShown;

  void _handleSortChange(
    ColumnData<T> columnData, {
    ColumnData<T>? secondarySortColumn,
  }) {
    SortDirection direction;
    if (columnData.title == widget.sortColumn!.title) {
      direction = widget.sortDirection!.reverse();
    } else if (columnData.numeric) {
      direction = SortDirection.descending;
    } else {
      direction = SortDirection.ascending;
    }
    widget.onSortChanged!(
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
              groupWidth += _columnSpacing;
            }
          }
          return Container(
            alignment: Alignment.center,
            width: groupWidth,
            child: Text(group.title),
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
        horizontal: (_columnGroupSpacingWithPadding - _columnGroupSpacing) / 2,
      ),
      child: Container(
        width: _columnGroupSpacing,
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
}

enum _TableRowPartDisplayType {
  column,
  columnSpacer,
  columnGroupSpacer,
}

extension _TableListExtension<T> on List<T> {
  int get numSpacers => max(0, length - 1);
}

abstract class SortableTable<T> {
  void sortData(ColumnData<T> column, SortDirection direction);
}

int _compareFactor(SortDirection direction) =>
    direction == SortDirection.ascending ? 1 : -1;

int _compareData<T>(
  T a,
  T b,
  ColumnData<T> column,
  SortDirection direction, {
  ColumnData<T>? secondarySortColumn,
}) {
  final compare = column.compare(a, b) * _compareFactor(direction);
  if (compare != 0 || secondarySortColumn == null) return compare;

  return secondarySortColumn.compare(a, b) * _compareFactor(direction);
}
