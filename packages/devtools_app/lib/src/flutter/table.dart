import 'dart:math';

import 'package:flutter/material.dart';

import '../table_data.dart';
import '../trees.dart';
import 'collapsible_mixin.dart';

/// A table that shows [TreeNode]s.
///
/// This takes in a collection of [data], and a collection of [ColumnData].
/// It takes at most one [TreeColumnData].
///
/// The [ColumnData] gives this table information about how to size its
/// columns, how to present each row of `data`, and which rows to show.
///
/// To lay the contents out, this table's [_TreeTableState] creates a flattened
/// list of the tree hierarchy. It then adds the nesting level of the
/// deepest row in [data] that is currently visible with the prescribed
/// width of each row in the table.
class TreeTable<T extends TreeNode<T>> extends StatefulWidget {
  TreeTable({
    Key key,
    @required this.columns,
    @required this.treeColumn,
    @required this.data,
    @required this.keyFactory,
  })  : assert(columns.contains(treeColumn)),
        assert(columns != null),
        assert(keyFactory != null),
        assert(data != null),
        super(key: key);

  /// The columns to show in this table.
  final List<ColumnData<T>> columns;

  /// The column of the table to treat as expandable.
  final TreeColumnData<T> treeColumn;

  /// The tree structure of rows to show in this table.
  final T data;

  /// Factory that creates keys for each row in this table.
  ///
  /// It uses [PageStorageKey] to restore the table's state when re-opening
  /// its page.
  final String Function(T data) keyFactory;

  @override
  _TreeTableState<T> createState() => _TreeTableState<T>();
}

class _TreeTableState<T extends TreeNode<T>> extends State<TreeTable<T>>
    with TickerProviderStateMixin {
  List<T> _flattenedList = [];

  /// The width of each column in this table, including the
  /// appropriate indentation for nested rows.
  ///
  /// This is computed in [_computeColumnWidths].
  List<double> columnWidths = [];

  /// The width of all columns in the table.
  double get tableWidth {
    double sum = 2 * rowHorizontalPadding;
    for (var width in columnWidths) {
      sum += width;
    }
    return sum;
  }

  /// The width to assume for columns that don't specify a width.
  static const defaultColumnWidth = 500.0;

  /// The maximum height to allow for rows in the table.
  ///
  /// When rows in the table expand or collapse, they will animate between
  /// a height of 0 and a height of [defaultRowHeight].
  static const defaultRowHeight = 42.0;

  /// How much padding to place around the beginning
  /// and end of each row in the table.
  static const rowHorizontalPadding = 16.0;

  @override
  void initState() {
    super.initState();
    _refreshTree();
  }

  @override
  void didUpdateWidget(TreeTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // TODO(djshuckerow): Be selective about running this only
    // when the members of the oldWidget have changed.
    // We need to be careful that we don't ignore a change to the tree
    // when the tree has had a child added to it but not been replaced.
    // The TableData class may provide some utilities for managing computations
    // necessary when the table is rebuilt.
    _refreshTree();
  }

  void _computeFlatListFromTree(
      {T node, bool Function(T node) filter, @required List<T> flatList}) {
    node ??= widget.data;
    filter ??= (_) => true;
    if (node == null) {
      return;
    }
    flatList.add(node);
    if (filter(node)) {
      for (var child in node.children) {
        _computeFlatListFromTree(
          node: child,
          filter: filter,
          flatList: flatList,
        );
      }
    }
    return;
  }

  /// Determines the width of all columns, including the columns that
  /// use indentation to show the nesting of the table.
  List<double> _computeColumnWidths() {
    final root = widget.data;
    TreeNode deepest = root;
    // This will use the width of all rows in the table, even the rows
    // that are hidden by nesting.
    // We may want to change this to using a flattened list of only
    // the list items that should show right now.
    for (var node in _flattenedList) {
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
        width += defaultColumnWidth;
      }
      widths.add(width);
    }
    return widths;
  }

  /// Recomputes the flattened list of the tree and the widths of the columns.
  ///
  /// This computation traverses every row to show in the table, which can become
  /// expensive for large tables.
  void _refreshTree() {
    setState(() {
      _flattenedList = [];
      _computeFlatListFromTree(flatList: _flattenedList);
      columnWidths = _computeColumnWidths();
    });
  }

  /// Rebuilds the table whenever the tree structure has been updated
  ///
  /// [TreeNodeWidgets] call this method when they have told a [TreeNode]
  /// to expand or collapse.
  ///
  /// Note that setState is being called in response to a change in
  /// [widget.node] or its children, and it does not reflect a change in
  /// an instance variable.
  void onNodeExpansionChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: max(
              constraints.widthConstraints().maxWidth,
              tableWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TreeNodeWidget.tableHeader(
                  key: const Key('Table header'),
                  tableState: this,
                ),
                Expanded(
                  child: Scrollbar(
                    child: ListView.custom(
                      childrenDelegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final node = _flattenedList[index];
                          return _TreeNodeWidget(
                            key: PageStorageKey(widget.keyFactory(node)),
                            tableState: this,
                            node: node,
                          );
                        },
                        childCount: _flattenedList.length,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Presents a [TreeNode].
///
/// When the given [node] is null, this widget will instead present
/// column headings.
class _TreeNodeWidget<T extends TreeNode<T>> extends StatefulWidget {
  /// Constructs a [_TreeNodeWidget] that presents the column values for
  /// [node].
  const _TreeNodeWidget({
    @required Key key,
    @required this.node,
    @required this.tableState,
  }) : super(key: key);

  /// Constructs a [_TreeNodeWidget] that presents the column titles instead
  /// of any [TreeNode].
  const _TreeNodeWidget.tableHeader({
    @required Key key,
    @required this.tableState,
  })  : node = null,
        super(key: key);

  final _TreeTableState<T> tableState;
  final T node;

  @override
  _TreeNodeState createState() => _TreeNodeState<T>();
}

class _TreeNodeState<T extends TreeNode<T>> extends State<_TreeNodeWidget<T>>
    with TickerProviderStateMixin, CollapsibleAnimationMixin {
  // Convenience accessors for relevant fields from [TreeTable].
  TreeColumnData<T> get treeColumn => widget.tableState.widget.treeColumn;

  List<ColumnData<T>> get columns => widget.tableState.widget.columns;

  void onListUpdated() => widget.tableState.onNodeExpansionChanged();

  List<double> get columnWidths => widget.tableState.columnWidths;

  void _toggleExpanded() {
    setExpanded(!widget.node.isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final title = tableRowFor(context);
    return AnimatedBuilder(
      animation: showController,
      builder: (context, child) {
        return SizedBox(
          height: _TreeTableState.defaultRowHeight * showAnimation.value,
          child: Material(child: child),
        );
      },
      child: InkWell(
        onTap: _toggleExpanded,
        child: title,
      ),
    );
  }

  /// Presents the content of this row.
  // TODO(djshuckerow): Pull this out for use as a separate widget in unnested
  // tables.
  Widget tableRowFor(BuildContext context) {
    Widget columnFor(ColumnData<T> column, double columnWidth) {
      Widget content;
      if (widget.node == null) {
        content = Text(
          column.title,
          overflow: TextOverflow.ellipsis,
        );
      } else {
        final padding = column.getNodeIndentPx(widget.node);
        content = Text(
          column.getDisplayValue(widget.node),
          overflow: TextOverflow.ellipsis,
        );
        if (column == treeColumn) {
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.node.isExpandable
                  ? RotationTransition(
                      turns: expandAnimation,
                      child: Icon(
                        Icons.expand_more,
                        size: 16.0,
                      ),
                    )
                  : const SizedBox(width: 16.0, height: 16.0),
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
      Alignment alignmentFor(ColumnData<T> column) {
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

      content = SizedBox(
        width: columnWidth,
        child: Align(
          alignment: alignmentFor(column),
          child: content,
        ),
      );
      return content;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _TreeTableState.rowHorizontalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < columns.length; i++)
            columnFor(
              columns[i],
              columnWidths[i],
            ),
        ],
      ),
    );
  }

  @override
  bool get isExpanded => widget.node?.isExpanded ?? false;

  @override
  void onExpandChanged(bool isExpanded) {
    setState(() {
      if (isExpanded) {
        widget.node.expand();
      } else {
        widget.node.collapse();
      }
      onListUpdated();
    });
  }

  @override
  bool shouldShow() => widget.node?.shouldShow() ?? true;
}
