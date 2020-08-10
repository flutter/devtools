import 'dart:math';

import 'package:flutter/material.dart' hide TableRow;
import 'package:flutter/services.dart';

import 'auto_dispose_mixin.dart';
import 'collapsible_mixin.dart';
import 'common_widgets.dart';
import 'common_widgets.dart' show ScrollControllerAutoScroll;
import 'flutter_widgets/linked_scroll_controller.dart';
import 'table_data.dart';
import 'theme.dart';
import 'tree.dart';
import 'trees.dart';
import 'utils.dart';

// TODO(devoncarew): We need to render the selected row with a different
// background color.

/// The maximum height to allow for rows in the table.
///
/// When rows in the table expand or collapse, they will animate between a
/// height of 0 and a height of [defaultRowHeight].
const defaultRowHeight = 32.0;

typedef IndexedScrollableWidgetBuilder = Widget Function(
  BuildContext,
  LinkedScrollControllerGroup linkedScrollControllerGroup,
  int index,
  List<double> columnWidths,
);

typedef TableKeyEventHandler = bool Function(RawKeyEvent event,
    ScrollController scrollController, BoxConstraints constraints);

enum ScrollKind { up, down, parent }

/// A table that displays in a collection of [data], based on a collection of
/// [ColumnData].
///
/// The [ColumnData] gives this table information about how to size its columns,
/// and how to present each row of `data`.
class FlatTable<T> extends StatefulWidget {
  const FlatTable({
    Key key,
    @required this.columns,
    @required this.data,
    this.autoScrollContent = false,
    @required this.keyFactory,
    @required this.onItemSelected,
    @required this.sortColumn,
    @required this.sortDirection,
    this.onSortChanged,
  })  : assert(columns != null),
        assert(keyFactory != null),
        assert(data != null),
        assert(onItemSelected != null),
        super(key: key);

  final List<ColumnData<T>> columns;

  final List<T> data;

  /// Auto-scrolling the table to keep new content visible.
  final bool autoScrollContent;

  /// Factory that creates keys for each row in this table.
  final Key Function(T data) keyFactory;

  final ItemCallback<T> onItemSelected;

  final ColumnData<T> sortColumn;

  final SortDirection sortDirection;

  final Function(ColumnData<T> column, SortDirection direction) onSortChanged;

  @override
  FlatTableState<T> createState() => FlatTableState<T>();
}

class FlatTableState<T> extends State<FlatTable<T>>
    implements SortableTable<T> {
  List<T> data;

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
    sortData(widget.sortColumn, widget.sortDirection);
  }

  List<double> _computeColumnWidths(double maxWidth) {
    maxWidth -= 2 * defaultSpacing;

    final unconstrainedCount =
        widget.columns.where((col) => col.fixedWidthPx == null).length;
    final allocatedWidth = widget.columns.fold(0,
        (val, col) => col.fixedWidthPx == null ? val : col.fixedWidthPx + val);
    final available = maxWidth - allocatedWidth;

    final widths = <double>[];
    for (ColumnData<T> column in widget.columns) {
      final width = column.fixedWidthPx ?? (available / unconstrainedCount);
      widths.add(width);
    }
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidths = _computeColumnWidths(constraints.maxWidth);

        return _Table<T>(
          itemCount: data.length,
          columns: widget.columns,
          columnWidths: columnWidths,
          autoScrollContent: widget.autoScrollContent,
          rowBuilder: _buildRow,
          sortColumn: widget.sortColumn,
          sortDirection: widget.sortDirection,
          onSortChanged: _sortDataAndUpdate,
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
    return TableRow<T>(
      key: widget.keyFactory(node),
      linkedScrollControllerGroup: linkedScrollControllerGroup,
      node: node,
      onPressed: widget.onItemSelected,
      columns: widget.columns,
      columnWidths: columnWidths,
      backgroundColor: alternatingColorForIndexWithContext(index, context),
    );
  }

  void _sortDataAndUpdate(ColumnData column, SortDirection direction) {
    setState(() {
      sortData(column, direction);
      if (widget.onSortChanged != null) {
        widget.onSortChanged(column, direction);
      }
    });
  }

  @override
  void sortData(ColumnData column, SortDirection direction) {
    data.sort((T a, T b) => _compareData<T>(a, b, column, direction));
  }
}

class Selection<T> {
  Selection({
    this.node,
    this.nodeIndex,
    this.scrollIntoView = false,
  });

  final T node;
  final int nodeIndex;
  final bool scrollIntoView;
}

class SelectionNotifier<T> extends ValueNotifier<T> {
  SelectionNotifier(T) : super(T);
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
    Key key,
    @required this.columns,
    @required this.treeColumn,
    @required this.dataRoots,
    @required this.keyFactory,
    @required this.sortColumn,
    @required this.sortDirection,
    this.selectionNotifier,
  })  : assert(columns.contains(treeColumn)),
        assert(columns.contains(sortColumn)),
        assert(columns != null),
        assert(keyFactory != null),
        assert(dataRoots != null),
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

  final ValueNotifier<Selection<T>> selectionNotifier;

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
  T animatingNode;
  List<double> columnWidths;
  List<bool> rootsExpanded;
  FocusNode _focusNode;

  ValueNotifier<Selection<T>> selectionNotifier;

  FocusNode get focusNode => _focusNode;

  @override
  void initState() {
    super.initState();
    _initData();
    rootsExpanded =
        List.generate(dataRoots.length, (index) => dataRoots[index].isExpanded);
    _updateItems();
    _focusNode = FocusNode();
  }

  void expandParents(T parent) {
    if (parent == null) return;

    if (parent.parent?.index != -1) {
      expandParents(parent.parent);
    }

    if (parent != null && !parent.isExpanded) {
      _toggleNode(parent);
    }
  }

  @override
  void didUpdateWidget(TreeTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget == oldWidget) return;

    cancel();

    addAutoDisposeListener(selectionNotifier, () {
      setState(() {
        final node = selectionNotifier.value.node;
        expandParents(node?.parent);
      });
    });

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
    dataRoots = List.from(widget.dataRoots);
    sortData(widget.sortColumn, widget.sortDirection);

    selectionNotifier =
        widget.selectionNotifier ?? ValueNotifier<Selection<T>>(Selection<T>());
  }

  @override
  void dispose() {
    super.dispose();
    _focusNode.dispose();
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
    TreeNode deepest = firstRoot;
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
    for (ColumnData<T> column in widget.columns) {
      double width = column.getNodeIndentPx(deepest);
      if (column.fixedWidthPx != null) {
        width += column.fixedWidthPx;
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
      columns: widget.columns,
      itemCount: items.length,
      columnWidths: columnWidths,
      rowBuilder: _buildRow,
      sortColumn: widget.sortColumn,
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
      final isNodeSelected = selectionNotifier.value.node == node;
      node.index = index;
      return TableRow<T>(
        key: widget.keyFactory(node),
        linkedScrollControllerGroup: linkedScrollControllerGroup,
        node: node,
        onPressed: (item) => _onItemPressed(item, index),
        backgroundColor: isNodeSelected
            ? Theme.of(context).selectedRowColor
            : alternatingColorForIndexWithContext(index, context),
        columns: widget.columns,
        columnWidths: columnWidths,
        expandableColumn: widget.treeColumn,
        isExpanded: node.isExpanded,
        isExpandable: node.isExpandable,
        isShown: node.shouldShow(),
        expansionChildren:
            node != animatingNode || animatingChildrenSet.contains(node)
                ? null
                : [for (var child in animatingChildren) rowForNode(child)],
        onExpansionCompleted: _onItemsAnimated,
        // TODO(https://github.com/flutter/devtools/issues/1361): alternate table
        // row colors, even when the table has collapsed rows.
      );
    }

    final node = items[index];
    if (animatingChildrenSet.contains(node)) return const SizedBox();
    return rowForNode(node);
  }

  @override
  void sortData(ColumnData column, SortDirection direction) {
    final sortFunction = (T a, T b) => _compareData<T>(a, b, column, direction);
    void _sort(T dataObject) {
      dataObject.children
        ..sort(sortFunction)
        ..forEach(_sort);
    }

    dataRoots
      ..sort(sortFunction)
      ..forEach(_sort);
  }

  bool _handleKeyEvent(
    RawKeyEvent event,
    ScrollController scrollController,
    BoxConstraints constraints,
  ) {
    if (event is! RawKeyDownEvent) return false;

    // Exit early if we aren't handling the key
    if (![
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight
    ].contains(event.logicalKey)) return false;

    // If there is no selected node, choose the first one.
    if (selectionNotifier.value.node == null) {
      selectionNotifier.value = Selection(
        node: items[0],
        nodeIndex: 0,
      );
    }

    assert(selectionNotifier.value.node ==
        items[selectionNotifier.value.nodeIndex]);

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(ScrollKind.down, scrollController, constraints.maxHeight);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(ScrollKind.up, scrollController, constraints.maxHeight);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      // On left arrow collapse the row if it is expanded. If it is not, move
      // selection to its parent.
      if (selectionNotifier.value.node.isExpanded) {
        _toggleNode(selectionNotifier.value.node);
      } else {
        _moveSelection(
          ScrollKind.parent,
          scrollController,
          constraints.maxHeight,
        );
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      // On right arrow expand the row if possible, otherwise move selection down.
      if (selectionNotifier.value.node.isExpandable &&
          !selectionNotifier.value.node.isExpanded) {
        _toggleNode(selectionNotifier.value.node);
      } else {
        _moveSelection(
          ScrollKind.down,
          scrollController,
          constraints.maxHeight,
        );
      }
    }

    return true;
  }

  void _moveSelection(
    ScrollKind scrollKind,
    ScrollController scrollController,
    double viewportHeight,
  ) {
    // get the index of the first item fully visible in the viewport
    final firstItemIndex = (scrollController.offset / defaultRowHeight).ceil();

    // '-1' in the following calculations is needed because the header row
    // occupies space in the viewport so we must subtract it out.
    final minCompleteItemsInView =
        (viewportHeight / defaultRowHeight).floor() - 1;
    final lastItemIndex = firstItemIndex + minCompleteItemsInView - 1;
    int newSelectedNodeIndex;

    final selectionValue = selectionNotifier.value;
    final selectedNodeIndex = selectionValue.nodeIndex;
    switch (scrollKind) {
      case ScrollKind.down:
        newSelectedNodeIndex = min(selectedNodeIndex + 1, items.length - 1);
        break;
      case ScrollKind.up:
        newSelectedNodeIndex = max(selectedNodeIndex - 1, 0);
        break;
      case ScrollKind.parent:
        newSelectedNodeIndex =
            max(items.indexOf(selectionValue.node.parent), 0);
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
      selectionNotifier.value = Selection(
        node: newSelectedNode,
        nodeIndex: newSelectedNodeIndex,
        scrollIntoView: true,
      );
    });
  }

  void _sortDataAndUpdate(ColumnData column, SortDirection direction) {
    sortData(column, direction);
    _updateItems();
  }
}

class _Table<T> extends StatefulWidget {
  const _Table({
    Key key,
    @required this.itemCount,
    @required this.columns,
    @required this.columnWidths,
    @required this.rowBuilder,
    @required this.sortColumn,
    @required this.sortDirection,
    @required this.onSortChanged,
    this.focusNode,
    this.handleKeyEvent,
    this.autoScrollContent = false,
    this.selectionNotifier,
  }) : super(key: key);

  final int itemCount;

  final bool autoScrollContent;
  final List<ColumnData<T>> columns;
  final List<double> columnWidths;
  final IndexedScrollableWidgetBuilder rowBuilder;
  final ColumnData<T> sortColumn;
  final SortDirection sortDirection;
  final Function(ColumnData<T> column, SortDirection direction) onSortChanged;
  final FocusNode focusNode;
  final TableKeyEventHandler handleKeyEvent;
  final ValueNotifier<Selection<T>> selectionNotifier;

  /// The width to assume for columns that don't specify a width.
  static const defaultColumnWidth = 500.0;

  @override
  _TableState<T> createState() => _TableState<T>();
}

class _TableState<T> extends State<_Table<T>> with AutoDisposeMixin {
  LinkedScrollControllerGroup _linkedHorizontalScrollControllerGroup;
  ColumnData<T> sortColumn;
  SortDirection sortDirection;
  ScrollController scrollController;

  @override
  void initState() {
    super.initState();

    _linkedHorizontalScrollControllerGroup = LinkedScrollControllerGroup();
    sortColumn = widget.sortColumn;
    sortDirection = widget.sortDirection;
    scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(_Table oldWidget) {
    super.didUpdateWidget(oldWidget);

    cancel();

    // Detect selection changes but only care about scrollIntoView.
    addAutoDisposeListener(oldWidget.selectionNotifier, () {
      setState(() {
        final selection = oldWidget.selectionNotifier.value;
        if (selection.scrollIntoView) {
          final int selectedDisplayRow = selection.node.index;
          // TODO(terry): Optimize selecting row, if row's visible in
          //              the viewport just select otherwise jumpTo row.
          final newPos = selectedDisplayRow * defaultRowHeight;

          // TODO(terry): Should animate factor out _moveSelection to reuse here.
          scrollController.jumpTo(newPos);
        }
      });
    });
  }

  /// Return the number of visible rows above the selected node.
  // TODO(terry): Must refactory should be T not dynamic but that requires hanlding
  //              for both Table and TreeTable.
  int selectionRowNumber(dynamic selectedNode) {
    var scanNode = selectedNode;
    var parent = scanNode?.parent;

    assert(parent != null);

    var totalVisibleRowsAboveNode = 0;
    while (!scanNode.isRoot) {
      final rowsAbove = parent.children.indexWhere((node) {
        return scanNode == node;
      });

      if (rowsAbove > 0) {
        // Add parent row to the count.
        totalVisibleRowsAboveNode += rowsAbove + (parent.index >= 0 ? 1 : 0);
      }

      // Check all scanNode's parent siblings above current scanNode.
      for (final sibling in parent.children) {
        if (sibling == scanNode) break;

        // Any parent siblings above expanded? Count those rows too.
        if (sibling.isExpanded) {
          // Count of a parent node's children and parent, if expanded,
          // above selected node.
          totalVisibleRowsAboveNode += sibling.children.length + 1;
        }
      }

      scanNode = parent;
      parent = scanNode.parent;
    }

    // Return zero based row.
    return totalVisibleRowsAboveNode - 1;
  }

  @override
  void dispose() {
    scrollController.dispose();

    super.dispose();
  }

  /// The width of all columns in the table, with additional padding.
  double get tableWidth =>
      widget.columnWidths.reduce((x, y) => x + y) + (2 * defaultSpacing);

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
    final itemDelegate = SliverChildBuilderDelegate(
      _buildItem,
      childCount: widget.itemCount,
    );

    // If we're at the end already, scroll to expose the new content.
    if (widget.autoScrollContent) {
      if (scrollController.hasClients && scrollController.atScrollBottom) {
        scrollController.autoScrollToBottom();
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        width: max(
          constraints.widthConstraints().maxWidth,
          tableWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TableRow.tableHeader(
              key: const Key('Table header'),
              linkedScrollControllerGroup:
                  _linkedHorizontalScrollControllerGroup,
              columns: widget.columns,
              columnWidths: widget.columnWidths,
              sortColumn: sortColumn,
              sortDirection: sortDirection,
              onSortChanged: _sortData,
            ),
            Expanded(
              child: Scrollbar(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (a) => widget.focusNode?.requestFocus(),
                  child: Focus(
                    autofocus: true,
                    onKey: (_, event) => widget.handleKeyEvent != null
                        ? widget.handleKeyEvent(
                            event,
                            scrollController,
                            constraints,
                          )
                        : false,
                    focusNode: widget.focusNode,
                    child: ListView.custom(
                      controller: scrollController,
                      childrenDelegate: itemDelegate,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _sortData(ColumnData column, SortDirection direction) {
    sortDirection = direction;
    sortColumn = column;
    widget.onSortChanged(column, direction);
  }
}

/// If a [ColumnData] implements this interface, it can override how that cell
/// is rendered.
abstract class ColumnRenderer<T> {
  /// Render the given [data] to a [Widget].
  ///
  /// This method can return `null` to indicate that the default rendering
  /// should be used instead.
  Widget build(BuildContext context, T data);
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
    Key key,
    @required this.linkedScrollControllerGroup,
    @required this.node,
    @required this.columns,
    @required this.columnWidths,
    @required this.onPressed,
    this.backgroundColor,
    this.expandableColumn,
    this.expansionChildren,
    this.onExpansionCompleted,
    this.isExpanded = false,
    this.isExpandable = false,
    this.isShown = true,
  })  : sortColumn = null,
        sortDirection = null,
        onSortChanged = null,
        super(key: key);

  /// Constructs a [TableRow] that presents the column titles instead
  /// of any [node].
  const TableRow.tableHeader({
    Key key,
    @required this.linkedScrollControllerGroup,
    @required this.columns,
    @required this.columnWidths,
    @required this.sortColumn,
    @required this.sortDirection,
    @required this.onSortChanged,
    this.onPressed,
  })  : node = null,
        isExpanded = false,
        isExpandable = false,
        expandableColumn = null,
        isShown = true,
        backgroundColor = null,
        expansionChildren = null,
        onExpansionCompleted = null,
        super(key: key);

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final T node;
  final List<ColumnData<T>> columns;
  final ItemCallback<T> onPressed;
  final List<double> columnWidths;

  /// Which column, if any, should show expansion affordances
  /// and nested rows.
  final ColumnData<T> expandableColumn;

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
  final List<Widget> expansionChildren;
  final VoidCallback onExpansionCompleted;

  /// The background color of the row.
  ///
  /// If null, defaults to `Theme.of(context).canvasColor`.
  final Color backgroundColor;

  final ColumnData<T> sortColumn;

  final SortDirection sortDirection;

  final Function(ColumnData<T> column, SortDirection direction) onSortChanged;

  @override
  _TableRowState<T> createState() => _TableRowState<T>();
}

class _TableRowState<T> extends State<TableRow<T>>
    with TickerProviderStateMixin, CollapsibleAnimationMixin {
  Key contentKey;

  ScrollController scrollController;

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
        widget.onExpansionCompleted();
      }
    });
  }

  @override
  void didUpdateWidget(TableRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    setExpanded(widget.isExpanded);
    if (oldWidget.linkedScrollControllerGroup !=
        widget.linkedScrollControllerGroup) {
      scrollController?.dispose();
      scrollController = widget.linkedScrollControllerGroup.addAndGet();
    }
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = tableRowFor(context);

    final box = SizedBox(
      height: defaultRowHeight,
      child: Material(
        color: widget.backgroundColor ?? Theme.of(context).canvasColor,
        child: widget.onPressed != null
            ? InkWell(
                canRequestFocus: false,
                key: contentKey,
                onTap: () => widget.onPressed(widget.node),
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
            for (var c in widget.expansionChildren)
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
  Widget tableRowFor(BuildContext context) {
    Widget columnFor(ColumnData<T> column, double columnWidth) {
      Widget content;
      final node = widget.node;
      if (node == null) {
        final isSortColumn = column == widget.sortColumn;

        content = InkWell(
          canRequestFocus: false,
          onTap: () => _handleSortChange(column),
          child: Row(
            mainAxisAlignment: _mainAxisAlignmentFor(column),
            children: [
              if (isSortColumn)
                Icon(
                  widget.sortDirection == SortDirection.ascending
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: defaultIconSize,
                ),
              if (isSortColumn)
                const SizedBox(width: densePadding),
              // TODO: This Flexible wrapper was added to get the
              // network_profiler_test.dart tests to pass.
              Flexible(
                child: Text(
                  column.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      } else {
        final padding = column.getNodeIndentPx(node);

        if (column is ColumnRenderer) {
          content = (column as ColumnRenderer).build(context, node);
        }
        content ??= Text(
          column.getDisplayValue(node),
          overflow: TextOverflow.ellipsis,
          style: contentTextStyle(column),
          maxLines: 1,
        );

        if (column == widget.expandableColumn) {
          final expandIndicator = widget.isExpandable
              ? RotationTransition(
                  turns: expandArrowAnimation,
                  child: const Icon(
                    Icons.expand_more,
                    size: defaultIconSize,
                  ),
                )
              : const SizedBox(width: defaultIconSize, height: defaultIconSize);
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        itemCount: widget.columns.length,
        itemBuilder: (context, int i) => columnFor(
          widget.columns[i],
          widget.columnWidths[i],
        ),
      ),
    );
  }

  TextStyle contentTextStyle(ColumnData<T> column) {
    final textColor = column.getTextColor(widget.node);
    final fontStyle = fixedFontStyle(context);
    return textColor == null ? fontStyle : fontStyle.copyWith(color: textColor);
  }

  @override
  bool get isExpanded => widget.isExpanded;

  @override
  void onExpandChanged(bool expanded) {}

  @override
  bool shouldShow() => widget.isShown;

  void _handleSortChange(ColumnData<T> columnData) {
    SortDirection direction;
    if (columnData.title == widget.sortColumn.title) {
      direction = widget.sortDirection.reverse();
    } else if (columnData.numeric) {
      direction = SortDirection.descending;
    } else {
      direction = SortDirection.ascending;
    }
    widget.onSortChanged(columnData, direction);
  }
}

abstract class SortableTable<T> {
  void sortData(ColumnData column, SortDirection direction);
}

int _compareFactor(SortDirection direction) =>
    direction == SortDirection.ascending ? 1 : -1;

int _compareData<T>(T a, T b, ColumnData column, SortDirection direction) {
  return column.compare(a, b) * _compareFactor(direction);
}
