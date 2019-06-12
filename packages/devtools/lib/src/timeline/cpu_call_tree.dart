// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import '../tables.dart';
import '../ui/elements.dart';
import '../utils.dart';
import 'cpu_profile_model.dart';
import 'timeline_controller.dart';

const _timeColumnWidth = 145;

class CpuCallTree extends CoreElement {
  CpuCallTree(this.timelineController)
      : super('div', classes: 'ui-details-section') {
    flex();
    layoutVertical();

    _init();
  }

  final TimelineController timelineController;

  TreeTable<CpuStackFrame> callTreeTable;

  bool tableNeedsRebuild = false;

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
      ..setSortColumn(callTreeTable.columns.first)
      ..setRows(<CpuStackFrame>[]);
    add(callTreeTable.element);
  }

  void update() {
    // Update the table if the call tree is visible. Otherwise, mark the table
    // as needing a rebuild.
    if (!isHidden) {
      final CpuStackFrame root =
          timelineController.timelineData.cpuProfileData.cpuProfileRoot;

      // Expand the root stack frame to start.
      final List<CpuStackFrame> rows = [root..isExpanded = true]
        ..addAll(root.children.cast());
      callTreeTable.setRows(rows);
    } else {
      tableNeedsRebuild = true;
    }
  }

  void show() async {
    attribute('hidden', false);

    if (tableNeedsRebuild) {
      tableNeedsRebuild = false;
      update();
    }
  }

  void hide() {
    attribute('hidden', true);
  }
}

class SelfTimeColumn extends Column<CpuStackFrame> {
  SelfTimeColumn() : super('Self Time', fixedWidthPx: _timeColumnWidth);

  @override
  bool get numeric => true;

  @override
  dynamic getValue(CpuStackFrame dataObject) => dataObject.selfTimeRatio;

  @override
  String getDisplayValue(CpuStackFrame dataObject) =>
      '${msText(dataObject.selfTime, fractionDigits: 2)} '
      '(${percent2(dataObject.selfTimeRatio)})';
}

class TotalTimeColumn extends Column<CpuStackFrame> {
  TotalTimeColumn() : super('Total Time', fixedWidthPx: _timeColumnWidth);

  @override
  bool get numeric => true;

  @override
  dynamic getValue(CpuStackFrame dataObject) => dataObject.totalTimeRatio;

  @override
  String getDisplayValue(CpuStackFrame dataObject) =>
      '${msText(dataObject.totalTime, fractionDigits: 2)} '
      '(${percent2(dataObject.totalTimeRatio)})';
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
  dynamic getDisplayValue(CpuStackFrame dataObject) => dataObject.simplifiedUrl;

  @override
  String getTooltip(CpuStackFrame dataObject) => dataObject.url;

  @override
  bool get supportsSorting => true;
}
