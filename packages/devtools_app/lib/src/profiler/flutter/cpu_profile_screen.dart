// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../flutter/screen.dart';
import '../../performance/performance_controller.dart';
import '../../table_data.dart';
import '../../trees.dart';
import '../cpu_profile_columns.dart';
import '../cpu_profile_model.dart';

class PerformanceScreen extends Screen {
  const PerformanceScreen() : super('Performance');

  @override
  Widget build(BuildContext context) => const PerformanceBody();

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      text: name,
      icon: Icon(Icons.computer),
    );
  }
}

class PerformanceBody extends StatefulWidget {
  const PerformanceBody();

  @override
  PerformanceBodyState createState() => PerformanceBodyState();
}

class PerformanceBodyState extends State<PerformanceBody> {
  final PerformanceController _controller = PerformanceController();
  CpuProfileData data;

  @override
  void initState() {
    super.initState();
    _controller.startRecording();
    Future.delayed(const Duration(seconds: 1)).then((_) async {
      await _controller.stopRecording();
      _controller.cpuProfileTransformer.processData(_controller.cpuProfileData);
      setState(() {
        // Note: it's not really clear what the source of truth for data is.
        // We're copying a value out of the controller and storing it in this state.
        // There's no real reason to not just use it directly from the controller.
        // We also want a way of making sure that the controller doesn't change this value
        // without an update to this State instance.
        data = _controller.cpuProfileData;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return data == null
        ? const Center(child: CircularProgressIndicator())
        : CpuTable(data: data);
  }

  void handleProfile(CpuProfileData value) {
    setState(() {
      data = value;
    });
  }
}

class CpuTable extends StatelessWidget {
  const CpuTable({Key key, this.data}) : super(key: key);
  static final columns = [];

  final CpuProfileData data;
  @override
  Widget build(BuildContext context) {
    return DtTable<CpuStackFrame>(
      data: data.cpuProfileRoot,
      columns: [
        TotalTimeColumn(),
        SelfTimeColumn(),
        MethodNameColumn(),
      ],
      id: (frame) => frame.id,
    );
  }
}

class DtTable<T extends TreeNode<T>> extends StatefulWidget {
  const DtTable({
    Key key,
    @required this.columns,
    @required this.data,
    @required this.id,
  }) : super(key: key);
  final List<ColumnData<T>> columns;
  final T data;
  final String Function(T data) id;

  @override
  DtTableState<T> createState() => DtTableState<T>();
}

class DtTableState<T extends TreeNode<T>> extends State<DtTable<T>>
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

  void _refreshTree() {
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
              width: widthTween.evaluate(
                CurvedAnimation(
                    parent: resizeAnimation, curve: Curves.easeInOutCubic),
              ),
              child: child);
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TreeNodeWidget(
            columns: widget.columns,
            columnWidths: columnWidths,
            node: null,
            id: (_) => null,
            onListUpdated: _refreshTree,
          ),
          Expanded(
            child: ListView.custom(
              childrenDelegate: SliverChildListDelegate([
                for (var node in flattenedList)
                  TreeNodeWidget(
                    columns: widget.columns,
                    columnWidths: columnWidths,
                    node: node,
                    id: widget.id,
                    onListUpdated: _refreshTree,
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
    @required this.columns,
    @required this.columnWidths,
    @required this.id,
    @required this.onListUpdated,
  }) : super(key: key);

  final T node;
  final List<ColumnData<T>> columns;
  final String Function(T frame) id;
  final VoidCallback onListUpdated;
  final List<double> columnWidths;

  @override
  _TreeNodeState createState() => _TreeNodeState<T>();
}

class _TreeNodeState<T extends TreeNode<T>> extends State<TreeNodeWidget<T>>
    with TickerProviderStateMixin {
  AnimationController showController;
  bool show;

  @override
  void initState() {
    show = widget.node?.shouldShow() ?? true;
    showController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    if (show) {
      showController.forward();
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
      } else {
        widget.node.collapse();
      }
      widget.onListUpdated();
    });
  }

  void didUpdateWidget(Widget oldWidget) {
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
      key: PageStorageKey(widget.id(widget.node)),
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
        content = Text(
          column.getDisplayValue(widget.node),
          overflow: TextOverflow.ellipsis,
        );
        final padding = column.getNodeIndentPx(widget.node).toDouble();
        if (padding != 0.0) {
          content = Row(children: [
            RotationTransition(
              turns:
                  Tween<double>(begin: 0.0, end: 0.5).animate(showController),
              child: Icon(Icons.arrow_drop_down),
            ),
            content
          ]);
        }
        content = Padding(
          padding: EdgeInsets.only(
            left: padding,
          ),
          child: content,
        );
      }

      content = SizedBox(
        width: columnWidth,
        child: content,
      );
      return content;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.columns.length; i++)
          columnFor(
            widget.columns[i],
            widget.columnWidths[i],
          ),
      ],
    );
  }
}
