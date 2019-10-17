import 'dart:math';

import 'package:flutter/material.dart';

import '../table_data.dart';
import '../trees.dart';

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
  const TreeTable({
    Key key,
    @required this.columns,
    this.treeColumn,
    @required this.data,
    @required this.keyFactory,
  }) : super(key: key);

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
  /// This is computed in [_computeTableWidth].
  List<double> columnWidths = [];
  double get tableWidth => columnWidths.reduce((x, y) => x + y);

  AnimationController _resizeController;
  Animation<double> _resizeAnimation;
  Tween<double> _widthTween;

  /// The width to assume for columns that don't specify a width.
  static const defaultColumnWidth = 500.0;

  /// The maximum height to allow for rows in the table.
  static const defaultRowHeight = 42.0;

  @override
  void initState() {
    super.initState();
    widget.data.expandCascading();
    _flattenedList = _flattenExpandedTree();
    columnWidths = _computeTableWidth();
    _widthTween = Tween<double>(begin: tableWidth, end: tableWidth);
    _resizeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _resizeAnimation = CurvedAnimation(
      parent: _resizeController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(TreeTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _flattenedList = _flattenExpandedTree();
    refreshTree();
  }

  @override
  void dispose() {
    _resizeController.dispose();
    super.dispose();
  }

  List<T> _flattenExpandedTree({T node, bool Function(T node) filter}) {
    node ??= widget.data;
    filter ??= (_) => true;
    List<T> flattenedChildren = [];
    if (filter(node)) {
      flattenedChildren = [
        for (var child in node.children)
          ..._flattenExpandedTree(
            node: child,
            filter: filter,
          ),
      ];
    }
    return [node, ...flattenedChildren];
  }

  // Determines the width of all columns, including the columns that
  // use indentation to show the nesting of the table.
  List<double> _computeTableWidth() {
    // Size the table to only fit the items that are visible.
    final flattenedList = _flattenExpandedTree(filter: (n) => n.isExpanded);
    final root = flattenedList[0];
    TreeNode deepest = root;
    for (var node in flattenedList) {
      if (node.level > deepest.level) {
        deepest = node;
      }
    }
    final widths = <double>[];
    for (ColumnData<T> column in widget.columns) {
      double width = column.getNodeIndentPx(deepest).toDouble();
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

  /// Resizes the table when the tree structure has been updated.
  ///
  /// [TreeNodeWidgets] call this method when they have told a [TreeNode]
  /// to expand or collapse.
  void refreshTree() {
    setState(() {
      columnWidths = _computeTableWidth();
      _widthTween = Tween<double>(
        begin: _widthTween.evaluate(_resizeController),
        end: tableWidth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: AnimatedBuilder(
        animation: _resizeController,
        builder: (context, child) {
          return SizedBox(
            width: max(
              MediaQuery.of(context).size.width,
              _widthTween.evaluate(_resizeAnimation),
            ),
            child: child,
          );
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _TreeNodeWidget(
            node: null,
            tableState: this,
          ),
          Expanded(
            child: ListView.custom(
              childrenDelegate: SliverChildListDelegate([
                for (var node in _flattenedList)
                  _TreeNodeWidget(
                    tableState: this,
                    node: node,
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TreeNodeWidget<T extends TreeNode<T>> extends StatefulWidget {
  const _TreeNodeWidget({
    Key key,
    @required this.node,
    @required this.tableState,
  }) : super(key: key);

  final _TreeTableState<T> tableState;
  final T node;

  @override
  _TreeNodeState createState() => _TreeNodeState<T>();
}

class _TreeNodeState<T extends TreeNode<T>> extends State<_TreeNodeWidget<T>>
    with TickerProviderStateMixin {
  // Animation controllers for bringing each node into the list,
  // animating the size from 0 to the appropriate height.
  AnimationController showController;
  Animation<double> showAnimation;

  // Animation controllers for animating the expand/collapse icon.
  AnimationController expandController;
  Animation<double> expandAnimation;

  /// Whether or not this widget has been hidden.
  ///
  /// This is cached based on [TreeNode.shouldShow], which is
  /// O([TreeNode.level]) to compute.
  bool show;

  // Convenience accessors for relevant fields from [TreeTable].
  TreeColumnData<T> get treeColumn => widget.tableState.widget.treeColumn;
  List<ColumnData<T>> get columns => widget.tableState.widget.columns;
  String id(T data) =>
      data == null ? null : widget.tableState.widget.keyFactory(data);
  void onListUpdated() => widget.tableState.refreshTree();
  List<double> get columnWidths => widget.tableState.columnWidths;

  @override
  void initState() {
    super.initState();
    showController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    showAnimation = CurvedAnimation(
      curve: Curves.easeInOutCubic,
      parent: showController,
    );
    expandAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(curve: Curves.easeInOutCubic, parent: expandController),
    );
    show = widget.node?.shouldShow() ?? true;
    if (show) {
      showController.forward();
    }
    if (widget.node?.isExpanded ?? false) {
      expandController.forward();
    }
  }

  @override
  void dispose() {
    showController.dispose();
    expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    _setExpanded(!widget.node.isExpanded);
  }

  void _setExpanded(bool isExpanded) {
    setState(() {
      if (isExpanded) {
        widget.node.expand();
        expandController.forward();
      } else {
        widget.node.collapse();
        expandController.reverse();
      }
      onListUpdated();
    });
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    super.didUpdateWidget(oldWidget);
    show = widget.node?.shouldShow() ?? true;
    if (show) {
      showController.forward();
    } else {
      showController.reverse();
    }
    if (widget.node?.isExpanded ?? false) {
      expandController.forward();
    } else {
      expandController.reverse();
    }
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
      key: PageStorageKey(id(widget.node)),
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
        final padding = column.getNodeIndentPx(widget.node).toDouble();
        content = Text(
          column.getDisplayValue(widget.node),
          overflow: TextOverflow.ellipsis,
        );
        if (column == treeColumn) {
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: expandAnimation,
                child: Icon(
                  Icons.expand_more,
                  size: 16.0,
                ),
              ),
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < columns.length; i++)
          columnFor(
            columns[i],
            columnWidths[i],
          ),
      ],
    );
  }
}
