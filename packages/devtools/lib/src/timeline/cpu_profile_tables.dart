// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import '../tables.dart';
import '../url_utils.dart';
import '../utils.dart';
import 'cpu_profile_model.dart';
import 'cpu_profile_protocol.dart';
import 'cpu_profiler_view.dart';
import 'timeline_controller.dart';

const _timeColumnWidthPx = 145;

class CpuCallTree extends CpuProfilerView {
  CpuCallTree(TimelineController timelineController)
      : super(timelineController, CpuProfilerViewType.callTree) {
    flex();
    layoutVertical();

    _init();
  }

  TreeTable<CpuStackFrame> callTreeTable;

  void _init() {
    final methodNameColumn = MethodNameColumn()
      ..onNodeExpanded
          .listen((stackFrame) => callTreeTable.expandNode(stackFrame))
      ..onNodeCollapsed
          .listen((stackFrame) => callTreeTable.collapseNode(stackFrame));

    callTreeTable = TreeTable<CpuStackFrame>.virtual()
      ..addColumn(TotalTimeColumn())
      ..addColumn(SelfTimeColumn())
      ..addColumn(methodNameColumn)
      ..addColumn(SourceColumn());
    callTreeTable
      ..sortColumn = callTreeTable.columns.first
      ..setRows(<CpuStackFrame>[]);
    add(callTreeTable.element);
  }

  @override
  void rebuildView() {
    final CpuStackFrame root = timelineController
        .timelineData.cpuProfileData.cpuProfileRoot
        .deepCopy();

    // Expand the root stack frame to start.
    final List<CpuStackFrame> rows = [root..isExpanded = true]
      ..addAll(root.children.cast());
    callTreeTable.setRows(rows);
  }
}

class CpuBottomUp extends CpuProfilerView {
  CpuBottomUp(TimelineController timelineController)
      : super(timelineController, CpuProfilerViewType.bottomUp) {
    flex();
    layoutVertical();
    _init();
  }

  TreeTable<CpuStackFrame> bottomUpTable;

  void _init() {
    final methodNameColumn = MethodNameColumn()
      ..onNodeExpanded
          .listen((stackFrame) => bottomUpTable.expandNode(stackFrame))
      ..onNodeCollapsed
          .listen((stackFrame) => bottomUpTable.collapseNode(stackFrame));
    final selfTimeColumn = SelfTimeColumn();

    bottomUpTable = TreeTable<CpuStackFrame>.virtual()
      ..addColumn(TotalTimeColumn())
      ..addColumn(selfTimeColumn)
      ..addColumn(methodNameColumn)
      ..addColumn(SourceColumn());
    bottomUpTable
      ..sortColumn = selfTimeColumn
      ..setRows(<CpuStackFrame>[]);
    add(bottomUpTable.element);
  }

  @override
  void rebuildView() {
    final CpuStackFrame root =
        timelineController.timelineData.cpuProfileData.cpuProfileRoot;
    final List<CpuStackFrame> bottomUpRoots =
        BottomUpProfileProcessor().processData(root);
    bottomUpTable.setRows(bottomUpRoots);
  }
}

class SelfTimeColumn extends Column<CpuStackFrame> {
  SelfTimeColumn() : super('Self Time', fixedWidthPx: _timeColumnWidthPx);

  @override
  bool get numeric => true;

  @override
  dynamic getValue(CpuStackFrame dataObject) => dataObject.selfTimeRatio;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return '${msText(dataObject.selfTime, fractionDigits: 2)} '
        '(${percent2(dataObject.selfTimeRatio)})';
  }
}

class TotalTimeColumn extends Column<CpuStackFrame> {
  TotalTimeColumn() : super('Total Time', fixedWidthPx: _timeColumnWidthPx);

  @override
  bool get numeric => true;

  @override
  dynamic getValue(CpuStackFrame dataObject) => dataObject.totalTimeRatio;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return '${msText(dataObject.totalTime, fractionDigits: 2)} '
        '(${percent2(dataObject.totalTimeRatio)})';
  }
}

class MethodNameColumn extends TreeColumn<CpuStackFrame> {
  MethodNameColumn() : super('Method');

  static const maxMethodNameLength = 75;

  @override
  dynamic getValue(CpuStackFrame dataObject) => dataObject.name;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    if (dataObject.name.length > maxMethodNameLength) {
      return dataObject.name.substring(0, maxMethodNameLength) + '...';
    }
    return dataObject.name;
  }

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(CpuStackFrame dataObject) => dataObject.name;
}

// TODO(kenzie): make these urls clickable once we can jump to source.
class SourceColumn extends Column<CpuStackFrame> {
  SourceColumn() : super('Source', alignment: ColumnAlignment.right);

  @override
  dynamic getValue(CpuStackFrame dataObject) => dataObject.url;

  @override
  dynamic getDisplayValue(CpuStackFrame dataObject) {
    return getSimplePackageUrl(dataObject.url);
  }

  @override
  String getTooltip(CpuStackFrame dataObject) => dataObject.url;

  @override
  bool get supportsSorting => true;
}
