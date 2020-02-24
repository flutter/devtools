// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import '../html_tables.dart';
import 'cpu_profile_columns.dart';
import 'cpu_profile_model.dart';
import 'cpu_profile_transformer.dart';
import 'html_cpu_profiler.dart';

class HtmlCpuCallTree extends HtmlCpuProfilerView {
  HtmlCpuCallTree(CpuProfileDataProvider profileDataProvider)
      : super(CpuProfilerViewType.callTree, profileDataProvider) {
    flex();
    layoutVertical();

    _init();
  }

  HtmlTreeTable<CpuStackFrame> callTreeTable;

  void _init() {
    final methodNameColumn = MethodNameColumn()
      ..onNodeExpanded
          .listen((stackFrame) => callTreeTable.model.expandNode(stackFrame))
      ..onNodeCollapsed
          .listen((stackFrame) => callTreeTable.model.collapseNode(stackFrame));

    callTreeTable = HtmlTreeTable<CpuStackFrame>.virtual();
    callTreeTable.model
      ..addColumn(TotalTimeColumn())
      ..addColumn(SelfTimeColumn())
      ..addColumn(methodNameColumn)
      ..addColumn(SourceColumn());
    callTreeTable.model
      ..sortColumn = callTreeTable.model.columns.first
      ..setRows(<CpuStackFrame>[]);
    add(callTreeTable.element);
  }

  @override
  void rebuildView() {
    final CpuProfileData data = profileDataProvider();
    final CpuStackFrame root = data.cpuProfileRoot.deepCopy();

    // Expand the root stack frame to start.
    final rows = <CpuStackFrame>[
      root..expand(),
      ...root.children.cast(),
    ];
    callTreeTable.model.setRows(rows);
  }

  @override
  void reset() => callTreeTable.model.setRows(<CpuStackFrame>[]);
}

class HtmlCpuBottomUp extends HtmlCpuProfilerView {
  HtmlCpuBottomUp(CpuProfileDataProvider profileDataProvider)
      : super(CpuProfilerViewType.bottomUp, profileDataProvider) {
    flex();
    layoutVertical();
    _init();
  }

  HtmlTreeTable<CpuStackFrame> bottomUpTable;

  void _init() {
    final methodNameColumn = MethodNameColumn()
      ..onNodeExpanded
          .listen((stackFrame) => bottomUpTable.model.expandNode(stackFrame))
      ..onNodeCollapsed
          .listen((stackFrame) => bottomUpTable.model.collapseNode(stackFrame));
    final selfTimeColumn = SelfTimeColumn();

    bottomUpTable = HtmlTreeTable<CpuStackFrame>.virtual();
    bottomUpTable.model
      ..addColumn(TotalTimeColumn())
      ..addColumn(selfTimeColumn)
      ..addColumn(methodNameColumn)
      ..addColumn(SourceColumn())
      ..sortColumn = selfTimeColumn
      ..setRows(<CpuStackFrame>[]);
    add(bottomUpTable.element);
  }

  @override
  void rebuildView() {
    final CpuProfileData data = profileDataProvider();
    final List<CpuStackFrame> bottomUpRoots =
        BottomUpProfileTransformer.processData(data.cpuProfileRoot);
    bottomUpTable.model.setRows(bottomUpRoots);
  }

  @override
  void reset() => bottomUpTable.model.setRows(<CpuStackFrame>[]);
}
