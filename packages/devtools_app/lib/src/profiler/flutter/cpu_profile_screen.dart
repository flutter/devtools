// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../flutter/screen.dart';
import '../../flutter/table.dart';
import '../../performance/performance_controller.dart';
import '../../table_data.dart';
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
  CpuTable({Key key, this.data}) : super(key: key);

  final List<ColumnData<CpuStackFrame>> columns = List.unmodifiable([
    TotalTimeColumn(),
    SelfTimeColumn(),
    MethodNameColumn(),
    SourceColumn(),
  ]);

  final CpuProfileData data;
  @override
  Widget build(BuildContext context) {
    return TreeTable<CpuStackFrame>(
      data: data.cpuProfileRoot,
      columns: columns,
      treeColumn: columns[2],
      keyFactory: (frame) => frame.id,
    );
  }
}
