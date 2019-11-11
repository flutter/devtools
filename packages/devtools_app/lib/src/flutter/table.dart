import 'dart:math';

import 'package:flutter/material.dart';

import '../table_data.dart';
import '../trees.dart';
import 'collapsible_mixin.dart';

class FlatTable<T> extends StatefulWidget {
  const FlatTable({
    Key key,
    @required this.columns,
    @required this.data,
    @required this.keyFactory,
  })  : assert(columns != null),
        assert(keyFactory != null),
        assert(data != null),
        super(key: key);

  /// The columns to show in this table.
  final List<ColumnData<T>> columns;

  /// The tree structure of rows to show in this table.
  final List<T> data;

  /// Factory that creates keys for each row in this table.
  ///
  /// It uses [PageStorageKey] to restore the table's state when re-opening
  /// its page.
  final String Function(T data) keyFactory;

  @override
  _FlatTableState<T> createState() => _FlatTableState<T>();
}

class _FlatTableState<T> extends NestingTableState<T, FlatTable<T>> {
  @override
  bool get startAtBottom => true;

  @override
  TreeNode<TreeNode> asTreeNode(T node) => null;

  @override
  List<ColumnData<T>> get columns => widget.columns;

  @override
  List<double> computeColumnWidths(List<T> flattenedList) {
    final widths = <double>[];
    for (ColumnData<T> column in widget.columns) {
      double width;
      if (column.fixedWidthPx != null) {
        width = column.fixedWidthPx;
      } else {
        width = NestingTableState.defaultColumnWidth;
      }
      widths.add(width);
    }
    return widths;
  }

  @override
  List<T> computeFlattenedChildList() => widget.data.toList();

  @override
  String keyFactory(T node) => widget.keyFactory(node);

  @override
  TreeColumnData<TreeNode> get treeColumn => null;
}

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

class _TreeTableState<T extends TreeNode<T>>
    extends NestingTableState<T, TreeTable<T>> {
  @override
  List<ColumnData<T>> get columns => widget.columns;

  @override
  TreeColumnData<TreeNode> get treeColumn => widget.treeColumn;

  @override
  TreeNode<TreeNode> asTreeNode(T node) {
    return node;
  }

  @override
  String keyFactory(T node) => widget.keyFactory(node);

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

  @override
  List<double> computeColumnWidths(List<T> flattenedList) {
    final root = widget.data;
    TreeNode deepest = root;
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
        width += NestingTableState.defaultColumnWidth;
      }
      widths.add(width);
    }
    return widths;
  }

  @override
  List<T> computeFlattenedChildList() {
    final flattenedList = <T>[];
    _computeFlatListFromTree(flatList: flattenedList);
    return flattenedList;
  }
}

/// A [State] for a table that may have nested rows.
///
/// Provides a consistent table layout for all rows.
abstract class NestingTableState<T, S extends StatefulWidget> extends State<S> {
  @override
  void initState() {
    super.initState();
    _refreshTree();
  }

  @override
  void didUpdateWidget(S oldWidget) {
    super.didUpdateWidget(oldWidget);
    // TODO(djshuckerow): Be selective about running this only
    // when the members of the oldWidget have changed.
    // We need to be careful that we don't ignore a change to the tree
    // when the tree has had a child added to it but not been replaced.
    // The TableData class may provide some utilities for managing computations
    // necessary when the table is rebuilt.
    _refreshTree();
  }

  void _refreshTree() {
    setState(() {
      _flattenedList = computeFlattenedChildList();
      _columnWidths = computeColumnWidths(_flattenedList);
    });
  }

  /// Recomputes the flattened list of the tree and the widths of the columns.
  ///
  /// In a nested this, this must inline the members of the list.
  ///
  /// This computation traverses every row to show in the table, which can become
  /// expensive for large tables.
  List<T> computeFlattenedChildList();

  List<T> _flattenedList = <T>[];

  /// Determines the width of all columns, including the columns that
  /// use indentation to show the nesting of the table.
  List<double> computeColumnWidths(List<T> flattenedList);

  /// The width of each column in this table, including the
  /// appropriate indentation for nested rows.
  ///
  /// This is computed in [_computeColumnWidths].
  List<double> get columnWidths => _columnWidths;

  List<double> _columnWidths;

  /// The width of all columns in the table.
  double get tableWidth {
    double sum = 2 * rowHorizontalPadding;
    for (var width in _columnWidths) {
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

  /// Returns [node] as a TreeNode, if it is a tree node, or null otherwise.
  TreeNode asTreeNode(T node);

  /// Generates a key for [node].
  String keyFactory(T node);

  /// The columns to show in the table.
  List<ColumnData<T>> get columns;

  /// The column from [columns] that should be used to show the table
  /// nesting in a nested table.
  TreeColumnData get treeColumn;

  /// Whether to scroll from the top to the bottom or vice-versa.
  ///
  /// If false, the list view starts at the top and scrolls down.
  ///
  /// See [ScrollView.reverse] for more.
  bool get startAtBottom => false;

  /// Rebuilds the table whenever the tree structure has been updated
  ///
  /// [_TableRow]s call this method when they have told a [TreeNode]
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
    final itemDelegate = SliverChildBuilderDelegate(
      (context, index) {
        if (startAtBottom) {
          index = _flattenedList.length - index - 1;
        }
        final node = _flattenedList[index];
        return _TableRow(
          key: PageStorageKey(keyFactory(node)),
          tableState: this,
          node: node,
        );
      },
      childCount: _flattenedList.length,
    );
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
                _TableRow.tableHeader(
                  key: const Key('Table header'),
                  tableState: this,
                ),
                Expanded(
                  child: Scrollbar(
                    child: ListView.custom(
                      reverse: startAtBottom,
                      childrenDelegate: itemDelegate,
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

/// Presents a [node] as a row in a table.
///
/// When the given [node] is null, this widget will instead present
/// column headings.
class _TableRow<T> extends StatefulWidget {
  /// Constructs a [_TableRow] that presents the column values for
  /// [node].
  const _TableRow({
    @required Key key,
    @required this.node,
    @required this.tableState,
  }) : super(key: key);

  /// Constructs a [_TableRow] that presents the column titles instead
  /// of any [TreeNode].
  const _TableRow.tableHeader({
    @required Key key,
    @required this.tableState,
  })  : node = null,
        super(key: key);

  final NestingTableState<T, StatefulWidget> tableState;
  final T node;

  @override
  _TableRowState createState() => _TableRowState<T>();
}

class _TableRowState<T> extends State<_TableRow<T>>
    with TickerProviderStateMixin, CollapsibleAnimationMixin {
  TreeColumnData get treeColumn => widget.tableState.treeColumn;

  List<ColumnData<T>> get columns => widget.tableState.columns;

  void onListUpdated() => widget.tableState.onNodeExpansionChanged();

  List<double> get columnWidths => widget.tableState.columnWidths;

  TreeNode get treeNode => widget.tableState.asTreeNode(widget.node);

  void _toggleExpanded() {
    setExpanded(!(treeNode?.isExpanded ?? true));
  }

  @override
  Widget build(BuildContext context) {
    final title = tableRowFor(context);
    return AnimatedBuilder(
      animation: showController,
      builder: (context, child) {
        return SizedBox(
          height: NestingTableState.defaultRowHeight * showAnimation.value,
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
          '${column.getDisplayValue(widget.node)}',
          overflow: TextOverflow.ellipsis,
        );
        if ((treeColumn as ColumnData<T>) == column && column != null) {
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isExpanded
                  ? RotationTransition(
                      turns: expandAnimation,
                      child: const Icon(
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
        horizontal: NestingTableState.rowHorizontalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
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
  bool get isExpanded => treeNode?.isExpanded ?? false;

  @override
  void onExpandChanged(bool expanded) {
    setState(() {
      if (expanded) {
        treeNode?.expand();
      } else {
        treeNode?.collapse();
      }
      onListUpdated();
    });
  }

  @override
  bool shouldShow() => treeNode?.shouldShow() ?? true;
}
