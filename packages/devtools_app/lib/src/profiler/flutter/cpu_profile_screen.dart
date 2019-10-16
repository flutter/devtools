// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/performance/performance_controller.dart';
import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/screen.dart';
import '../../table_data.dart';
import '../../trees.dart';
import '../../url_utils.dart';
import '../../utils.dart';
import '../cpu_profile_columns.dart';
import '../cpu_profile_model.dart';
import '../cpu_profile_service.dart';

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

  static Widget wrapWithColumnWidth<T extends TreeNode<T>>(
      ColumnData<T> columnData, TreeNode<T> treeNode, Widget content) {}
}

typedef TableRowBuilder = Widget Function(
  BuildContext context,
  List<Widget> row,
);

class DtTableState<T extends TreeNode<T>> extends State<DtTable<T>> {
  @override
  void initState() {
    super.initState();
    widget.data.expandCascading();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        TreeNodeWidget(columns: widget.columns, node: null, id: (_) => null),
        TreeNodeWidget(
            columns: widget.columns, node: widget.data, id: widget.id)
      ],
    );
  }
}

class TreeNodeWidget<T extends TreeNode<T>> extends StatefulWidget {
  const TreeNodeWidget({
    Key key,
    @required this.node,
    @required this.columns,
    @required this.id,
  }) : super(key: key);

  final T node;
  final List<ColumnData<T>> columns;
  final String Function(T frame) id;

  @override
  _TreeNodeState createState() => _TreeNodeState<T>();
}

class _TreeNodeState<T extends TreeNode<T>> extends State<TreeNodeWidget<T>> {
  @override
  Widget build(BuildContext context) {
    final title = tableRowFor(context);
    if (widget.node?.isExpandable ?? false) {
      return ExpansionTile(
        key: PageStorageKey(widget.id(widget.node)),
        title: title,
        initiallyExpanded: widget.node.isExpanded,
        onExpansionChanged: _setExpanded,
        children: <Widget>[
          for (var childFrame in widget.node.children)
            TreeNodeWidget<T>(
              node: childFrame,
              columns: widget.columns,
              id: widget.id,
            ),
        ],
      );
    }
    return ListTile(
      key: PageStorageKey(widget.id(widget.node)),
      title: title,
    );
  }

  void _setExpanded(bool isExpanded) {
    setState(() {
      if (isExpanded) {
        widget.node.expand();
      } else {
        widget.node.collapse();
      }
    });
  }

  Widget tableRowFor(BuildContext context) {
    Widget columnFor(ColumnData<T> column) {
      Widget content;
      if (widget.node == null) {
        content = Text(column.title);
      } else {
        content = Padding(
          padding: EdgeInsets.only(
            left: column.getNodeIndentPx(widget.node).toDouble(),
          ),
          child: Text(
            column.getDisplayValue(widget.node),
          ),
        );
      }

      if (column.fixedWidthPx != null) {
        content = SizedBox(
          width: column.fixedWidthPx.toDouble(),
          child: content,
        );
      }
      return content;
    }

    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            columnFor(widget.columns[i]),
        ],
      ),
    );
  }
}
