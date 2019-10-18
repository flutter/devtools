// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../flutter/screen.dart';
import '../../flutter/table.dart';
import '../../performance/performance_controller.dart';
import '../../profiler/cpu_profile_columns.dart';
import '../../profiler/cpu_profile_model.dart';
import '../../table_data.dart';

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
  CpuProfileData _data;

  @override
  void initState() {
    super.initState();
    // TODO(djshuckerow): add in buttons to control the CPU recording.
    _controller.startRecording();
    Future.delayed(const Duration(seconds: 1)).then((_) async {
      await _controller.stopRecording();
      _controller.cpuProfileTransformer.processData(_controller.cpuProfileData);
      setState(() {
        // Note: it's not really clear what the source of truth for data is.
        // We're copying a value out of the controller and storing it in
        // this state. There's no real reason to not just use it directly
        // from the controller. We also want a way of making sure that
        // the controller doesn't change this value without an update to this
        // State instance.
        _data = _controller.cpuProfileData;
        // TODO(djshuckerow): remove when this screen includes buttons to
        // expand/collapse all by default.
        _data.cpuProfileRoot.expandCascading();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return _data == null
        ? const Center(child: CircularProgressIndicator())
        : CpuCallTreeTable(data: _data);
  }

  void handleProfile(CpuProfileData value) {
    setState(() {
      _data = value;
    });
  }
}

/// A table of the CPU's call tree.
class CpuCallTreeTable extends StatelessWidget {
  factory CpuCallTreeTable({Key key, CpuProfileData data}) {
    final treeColumn = MethodNameColumn();
    final columns = List<ColumnData<CpuStackFrame>>.unmodifiable([
      TotalTimeColumn(),
      SelfTimeColumn(),
      treeColumn,
      SourceColumn(),
    ]);
    return CpuCallTreeTable._(key, data, treeColumn, columns);
  }
  const CpuCallTreeTable._(Key key, this.data, this.treeColumn, this.columns)
      : super(key: key);

  final TreeColumnData<CpuStackFrame> treeColumn;
  final List<ColumnData<CpuStackFrame>> columns;

  final CpuProfileData data;
  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      data: data.cpuProfileRoot,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (frame) => frame.id,
    );
  }
}
