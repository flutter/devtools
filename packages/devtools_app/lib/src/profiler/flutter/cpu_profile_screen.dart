// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/screen.dart';

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
  List<CpuData> data = const [
    CpuData('foo', 0, [
      CpuData('foo.bar', 1, [
        CpuData('foo.bar.baz', 2, []),
        CpuData('foo.bar.qux', 2, []),
      ]),
      CpuData('foo.baz', 1, []),
      CpuData('foo.qux', 1, []),
    ]),
    CpuData('bar', 0, [
      CpuData('bar.foo', 1, []),
      CpuData('bar.baz', 1, []),
      CpuData('bar.qux', 1, []),
    ]),
  ];

  List<CollapsingTableColumn<CpuData>> columns = [
    CollapsingTableColumn(
      buildHeader: (context, sortIndicator) =>
          Row(children: [const Text('Name'), sortIndicator]),
      build: (context, item) => Row(children: [
        SizedBox(width: item.depth * 2.0),
        Text(item.name),
      ]),
      comparator: (d1, d2) => d1.name.compareTo(d2.name),
    )
  ];

  @override
  Widget build(BuildContext context) {
    return CollapsingTable<CpuData>(columns: columns, data: data);
  }
}

class CpuData extends CollapsingData {
  const CpuData(this.name, this.depth, this.children);
  final String name;
  @override
  final int depth;
  @override
  final List<CpuData> children;
}
