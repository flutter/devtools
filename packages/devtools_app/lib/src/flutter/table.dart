import 'dart:math';

import 'package:flutter/material.dart';

import '../table_data.dart';
import '../trees.dart';

class TreeTable<T extends TreeNode<T>> extends StatefulWidget {
  const TreeTable({
    Key key,
    @required this.columns,
    this.treeColumn,
    @required this.data,
    @required this.id,
  }) : super(key: key);
  final List<ColumnData<T>> columns;

  /// The column of the table to treat as expandable.
  final TreeColumnData<T> treeColumn;
  final T data;
  final String Function(T data) id;

  @override
  TreeTableState<T> createState() => TreeTableState<T>();
}

class TreeTableState<T extends TreeNode<T>> extends State<TreeTable<T>>
    with TickerProviderStateMixin {
  List<T> flattenedList = [];
  List<double> columnWidths = [];
  double get tableWidth => columnWidths.reduce((x, y) => x + y);

  AnimationController resizeAnimation;
  Tween<double> widthTween;

  static const defaultColumnWidth = 500.0;

  @override
  void initState() {
    super.initState();
    widget.data.expandCascading();
    flattenedList = _flattenExpandedTree();
    columnWidths = _computeTableWidth();
    widthTween = Tween<double>(begin: tableWidth, end: tableWidth);
    resizeAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    resizeAnimation.dispose();
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
        // TODO(djshuckerow): measure the text of the longest content to get an idea for how wide this column should be.
        width += defaultColumnWidth;
      }
      widths.add(width);
    }
    return widths;
  }

  void refreshTree() {
    setState(() {
      flattenedList = _flattenExpandedTree();
      columnWidths = _computeTableWidth();
      widthTween = Tween<double>(
        begin: widthTween.evaluate(resizeAnimation),
        end: tableWidth,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: AnimatedBuilder(
        animation: resizeAnimation,
        builder: (context, child) {
          return SizedBox(
            width: max(
              MediaQuery.of(context).size.width,
              widthTween.evaluate(
                CurvedAnimation(
                  parent: resizeAnimation,
                  curve: Curves.easeInOutCubic,
                ),
              ),
            ),
            child: child,
          );
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TreeNodeWidget(
            node: null,
            tableState: this,
          ),
          Expanded(
            child: ListView.custom(
              childrenDelegate: SliverChildListDelegate([
                for (var node in flattenedList)
                  TreeNodeWidget(
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

class TreeNodeWidget<T extends TreeNode<T>> extends StatefulWidget {
  const TreeNodeWidget({
    Key key,
    @required this.node,
    @required this.tableState,
  }) : super(key: key);

  final TreeTableState<T> tableState;
  final T node;

  @override
  _TreeNodeState createState() => _TreeNodeState<T>();
}

class _TreeNodeState<T extends TreeNode<T>> extends State<TreeNodeWidget<T>>
    with TickerProviderStateMixin {
  AnimationController showController;
  AnimationController expandController;
  bool show;

  TreeColumnData<T> get treeColumn => widget.tableState.widget.treeColumn;
  List<ColumnData<T>> get columns => widget.tableState.widget.columns;
  String id(T data) => data == null ? null : widget.tableState.widget.id(data);
  void onListUpdated() => widget.tableState.refreshTree();
  List<double> get columnWidths => widget.tableState.columnWidths;

  @override
  void initState() {
    super.initState();
    show = widget.node?.shouldShow() ?? true;
    showController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    expandController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        value: (widget.node?.isExpanded ?? false) ? 1.0 : 0.0);
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
  }

  @override
  Widget build(BuildContext context) {
    final title = tableRowFor(context);
    return AnimatedBuilder(
      animation: showController,
      builder: (context, child) {
        return SizedBox(
          height: 42.0 *
              CurvedAnimation(
                curve: Curves.easeInOutCubic,
                parent: showController,
              ).value,
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
                turns: Tween<double>(begin: 0.0, end: 0.5)
                    .animate(expandController),
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
