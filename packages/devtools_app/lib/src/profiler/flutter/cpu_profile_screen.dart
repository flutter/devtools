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
    return Table<CpuStackFrame>(
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

class Table<T extends TreeNode<T>> extends StatefulWidget {
  const Table({
    Key key,
    @required this.columns,
    @required this.data,
    @required this.id,
  }) : super(key: key);
  final List<ColumnData<T>> columns;
  final T data;
  final String Function(T data) id;

  @override
  TableState<T> createState() => TableState<T>();
}

class TableState<T extends TreeNode<T>> extends State<Table<T>> {
  @override
  Widget build(BuildContext context) {
    // This doesn't seem to make sense.  Why are we building a list with one item?
    // Switch to a custom listview builder, possibly.
    return GridView.count(
      crossAxisCount: 1,
      shrinkWrap: true,
      children: [
        Container(
          constraints: const BoxConstraints(
            maxWidth: 1000.0,
            maxHeight: 0.0,
          ),
          child: TreeNodeWidget<T>(
            node: widget.data,
            columns: widget.columns,
            id: widget.id,
          ),
        ),
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
    if (!widget.node.isExpandable) {
      return ListTile(
        key: PageStorageKey(widget.id(widget.node)),
        title: _buildContent(),
      );
    }

    return ExpansionTile(
      key: PageStorageKey(widget.id(widget.node)),
      title: _buildContent(),
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

  void _setExpanded(bool isExpanded) {
    setState(() {
      if (isExpanded) {
        widget.node.expand();
      } else {
        widget.node.collapse();
      }
    });
  }

  Widget _buildContent() {
    Widget present(ColumnData<T> column) {
      final text = Text(
        column.getDisplayValue(widget.node),
      );
      return text;
      Widget content = text;
      if (column.fixedWidthPx != null) {
        content = SizedBox(
          width: column.fixedWidthPx.toDouble(),
          child: text,
        );
      } else {
        // } else if (column.percentWidth != null) {
        content = text;
      }
      content = Padding(
        padding: EdgeInsets.only(
          left: column.getNodeIndentPx(widget.node) * 1.0,
        ),
        child: content,
      );
      // if (column.fixedWidthPx == null) {
      //   return Expanded(child: content);
      // } else {
      return content;
      // }
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 1000.0, maxHeight: 64.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var column in widget.columns) present(column),
        ],
      ),
    );
  }
}
