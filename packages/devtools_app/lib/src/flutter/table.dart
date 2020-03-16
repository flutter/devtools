import 'dart:math';

import 'package:flutter/material.dart' hide TableRow;

import '../table_data.dart';
import '../trees.dart';
import '../ui/theme.dart';
import '../utils.dart';
import 'collapsible_mixin.dart';
import 'flutter_widgets/linked_scroll_controller.dart';
import 'theme.dart';

typedef IndexedScrollableWidgetBuilder = Widget Function(
  BuildContext,
  LinkedScrollControllerGroup linkedScrollControllerGroup,
  int index,
);

/// A table that displays in a collection of [data], based on a collection
/// of [ColumnData].
///
/// The [ColumnData] gives this table information about how to size its
/// columns, and how to present each row of `data`
class FlatTable<T> extends StatefulWidget {
  const FlatTable({
    Key key,
    @required this.columns,
    @required this.data,
    @required this.keyFactory,
    @required this.onItemSelected,
    @required this.sortColumn,
    @required this.sortDirection,
  })  : assert(columns != null),
        assert(keyFactory != null),
        assert(data != null),
        assert(onItemSelected != null),
        super(key: key);

  final List<ColumnData<T>> columns;

  final List<T> data;

  /// Factory that creates keys for each row in this table.
  final Key Function(T data) keyFactory;

  final ItemCallback<T> onItemSelected;

  final ColumnData<T> sortColumn;

  final SortDirection sortDirection;

  @override
  FlatTableState<T> createState() => FlatTableState<T>();
}

class FlatTableState<T> extends State<FlatTable<T>>
    implements SortableTable<T> {
  List<double> columnWidths;

  List<T> data;

  @override
  void initState() {
    super.initState();
    _initData();
    columnWidths = _computeColumnWidths();
  }

  @override
  void didUpdateWidget(FlatTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sortColumn != oldWidget.sortColumn ||
        widget.sortDirection != oldWidget.sortDirection ||
        !collectionEquals(widget.data, oldWidget.data)) {
      _initData();
    }
    columnWidths = _computeColumnWidths();
  }

  void _initData() {
    data = List.from(widget.data);
    sortData(widget.sortColumn, widget.sortDirection);
  }

  List<double> _computeColumnWidths() {
    final widths = <double>[];
    for (ColumnData<T> column in widget.columns) {
      double width;
      if (column.fixedWidthPx != null) {
        width = column.fixedWidthPx;
      } else {
        width = _Table.defaultColumnWidth;
      }
      widths.add(width);
    }
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    return _Table<T>(
      itemCount: widget.data.length,
      columns: widget.columns,
      columnWidths: columnWidths,
      startAtBottom: true,
      rowBuilder: _buildRow,
      sortColumn: widget.sortColumn,
      sortDirection: widget.sortDirection,
      onSortChanged: _sortDataAndUpdate,
    );
  }

  Widget _buildRow(
    BuildContext context,
    LinkedScrollControllerGroup linkedScrollControllerGroup,
    int index,
  ) {
    final node = widget.data[index];
    return TableRow<T>(
      key: widget.keyFactory(node),
      linkedScrollControllerGroup: linkedScrollControllerGroup,
      node: node,
      onPressed: widget.onItemSelected,
      columns: widget.columns,
      columnWidths: columnWidths,
      backgroundColor: TableRow.colorFor(context, index),
    );
  }

  void _sortDataAndUpdate(ColumnData column, SortDirection direction) {
    setState(() {
      sortData(column, direction);
    });
  }

  @override
  void sortData(ColumnData column, SortDirection direction) {
    data.sort((T a, T b) => _compareData<T>(a, b, column, direction));
  }
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

  @override
  TreeTableState<T> createState() => TreeTableState<T>();
}

class TreeTableState<T extends TreeNode<T>> extends State<TreeTable<T>>
    with TickerProviderStateMixin
    implements SortableTable<T> {
  /// The number of items to show when animating out the tree table.
  static const itemsToShowWhenAnimating = 50;

  List<T> dataRoots;

  List<T> items;
  List<T> animatingChildren = [];
  Set<T> animatingChildrenSet = {};
  T animatingNode;
  List<double> columnWidths;
  List<bool> rootsExpanded;

  @override
  void initState() {
    super.initState();
    _initData();
    rootsExpanded =
        List.generate(dataRoots.length, (index) => dataRoots[index].isExpanded);
    _updateItems();
  }

  @override
  void didUpdateWidget(TreeTable oldWidget) {
    super.didUpdateWidget(oldWidget);
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
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _updateItems() {
    setState(() {
      items = _buildFlatList(dataRoots);
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

  void _onItemPressed(T node) {
    /// Rebuilds the table whenever the tree structure has been updated
    if (!node.isExpandable) return;
    setState(() {
      animatingNode = node;
      List<T> nodeChildren;
      if (node.isExpanded) {
        // Compute the children of the expanded node before collapsing.
        nodeChildren = _buildFlatList([node]);
        node.collapse();
      } else {
        node.expand();
        // Compute the children of the collapsed node after expanding it.
        nodeChildren = _buildFlatList([node]);
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
      double width =
          column.getNodeIndentPx(deepest, indentForTreeToggle: false);
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

  void traverse(T node, bool Function(T) callback) {
    if (node == null) return;
    final shouldContinue = callback(node);
    if (shouldContinue) {
      for (var child in node.children) {
        traverse(child, callback);
      }
    }
  }

  List<T> _buildFlatList(List<T> roots) {
    final flatList = <T>[];
    for (T root in roots) {
      traverse(root, (n) {
        flatList.add(n);
        return n.isExpanded;
      });
    }
    return flatList;
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
    );
  }

  Widget _buildRow(
    BuildContext context,
    LinkedScrollControllerGroup linkedScrollControllerGroup,
    int index,
  ) {
    Widget rowForNode(T node) {
      return TableRow<T>(
        key: widget.keyFactory(node),
        linkedScrollControllerGroup: linkedScrollControllerGroup,
        node: node,
        onPressed: _onItemPressed,
        backgroundColor: TableRow.colorFor(context, index),
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
    void _sort(T dataObject) {
      dataObject.children
        ..sort((T a, T b) => _compareData<T>(a, b, column, direction))
        ..forEach(_sort);
    }

    dataRoots.where((dataRoot) => dataRoot.level == 0).toList()
      ..sort((T a, T b) => _compareData<T>(a, b, column, direction))
      ..forEach(_sort);
  }

  void _sortDataAndUpdate(ColumnData column, SortDirection direction) {
    sortData(column, direction);
    _updateItems();
  }
}

class _Table<T> extends StatefulWidget {
  const _Table(
      {Key key,
      @required this.itemCount,
      @required this.columns,
      @required this.columnWidths,
      @required this.rowBuilder,
      @required this.sortColumn,
      @required this.sortDirection,
      @required this.onSortChanged,
      this.startAtBottom = false})
      : super(key: key);

  final int itemCount;
  final bool startAtBottom;
  final List<ColumnData<T>> columns;
  final List<double> columnWidths;
  final IndexedScrollableWidgetBuilder rowBuilder;
  final ColumnData<T> sortColumn;
  final SortDirection sortDirection;
  final Function(ColumnData<T> column, SortDirection direction) onSortChanged;

  /// The width to assume for columns that don't specify a width.
  static const defaultColumnWidth = 500.0;

  /// The maximum height to allow for rows in the table.
  ///
  /// When rows in the table expand or collapse, they will animate between
  /// a height of 0 and a height of [defaultRowHeight].
  static const defaultRowHeight = 42.0;

  @override
  _TableState<T> createState() => _TableState<T>();
}

class _TableState<T> extends State<_Table<T>> {
  LinkedScrollControllerGroup _linkedHorizontalScrollControllerGroup;
  ColumnData<T> sortColumn;
  SortDirection sortDirection;

  @override
  void initState() {
    super.initState();
    _linkedHorizontalScrollControllerGroup = LinkedScrollControllerGroup();
    sortColumn = widget.sortColumn;
    sortDirection = widget.sortDirection;
  }

  /// The width of all columns in the table, with additional padding.
  double get tableWidth =>
      widget.columnWidths.reduce((x, y) => x + y) + (2 * defaultSpacing);

  Widget _buildItem(BuildContext context, int index) {
    if (widget.startAtBottom) {
      index = widget.itemCount - index - 1;
    }

    return widget.rowBuilder(
      context,
      _linkedHorizontalScrollControllerGroup,
      index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemDelegate = SliverChildBuilderDelegate(
      _buildItem,
      childCount: widget.itemCount,
    );

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
                child: ListView.custom(
                  reverse: widget.startAtBottom,
                  childrenDelegate: itemDelegate,
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

  /// Gets a color to use for this row at a given index.
  static Color colorFor(BuildContext context, int index) {
    final theme = Theme.of(context);
    final alternateColor = ThemedColor(devtoolsGrey[50], devtoolsGrey[900]);
    return index % 2 == 0 ? alternateColor : theme.canvasColor;
  }

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
      height: _Table.defaultRowHeight,
      child: Material(
        color: widget.backgroundColor ?? Theme.of(context).canvasColor,
        child: widget.onPressed != null
            ? InkWell(
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
                height: _Table.defaultRowHeight * expandCurve.value,
                child: OverflowBox(
                  minHeight: 0.0,
                  maxHeight: _Table.defaultRowHeight,
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

  /// Presents the content of this row.
  Widget tableRowFor(BuildContext context) {
    Widget columnFor(ColumnData<T> column, double columnWidth) {
      Widget content;
      final node = widget.node;
      if (node == null) {
        final isSortColumn = column.title == widget.sortColumn.title;
        content = InkWell(
          onTap: () => _handleSortChange(column),
          child: Row(
            children: [
              if (isSortColumn)
                Icon(
                  widget.sortDirection == SortDirection.ascending
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: defaultIconSize,
                ),
              const SizedBox(width: 4.0),
              Text(
                column.title,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      } else {
        final padding =
            column.getNodeIndentPx(node, indentForTreeToggle: false);
        content = Text(
          '${column.getDisplayValue(node)}',
          overflow: TextOverflow.ellipsis,
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
