// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/globals.dart';
import '../../shared/profiler_utils.dart';
import '../../shared/routing.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../debugger/codeview_controller.dart';
import '../debugger/debugger_screen.dart';
import '../vm_developer/vm_developer_common_widgets.dart';
import 'cpu_profile_model.dart';

class SelfTimeColumn extends TimeAndPercentageColumn<CpuStackFrame> {
  SelfTimeColumn({
    String? titleTooltip,
    RichTooltipBuilder<CpuStackFrame>? dataTooltipProvider,
  }) : super(
          title: 'Self Time',
          titleTooltip: titleTooltip,
          timeProvider: (stackFrame) => stackFrame.selfTime,
          percentAsDoubleProvider: (stackFrame) => stackFrame.selfTimeRatio,
          richTooltipProvider: dataTooltipProvider,
          secondaryCompare: (stackFrame) => stackFrame.name,
        );
}

class TotalTimeColumn extends TimeAndPercentageColumn<CpuStackFrame> {
  TotalTimeColumn({
    String? titleTooltip,
    RichTooltipBuilder<CpuStackFrame>? dataTooltipProvider,
  }) : super(
          title: 'Total Time',
          titleTooltip: titleTooltip,
          timeProvider: (stackFrame) => stackFrame.totalTime,
          percentAsDoubleProvider: (stackFrame) => stackFrame.totalTimeRatio,
          richTooltipProvider: dataTooltipProvider,
          secondaryCompare: (stackFrame) => stackFrame.name,
        );
}

class MethodAndSourceColumn extends TreeColumnData<CpuStackFrame>
    implements ColumnRenderer<CpuStackFrame> {
  MethodAndSourceColumn() : super('Method');

  @override
  String getValue(CpuStackFrame dataObject) => dataObject.name;

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(CpuStackFrame dataObject) => '';

  @override
  Widget? build(
    BuildContext context,
    CpuStackFrame data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return MethodAndSourceDisplay(
      methodName: data.name,
      packageUri: data.packageUri,
      sourceLine: data.sourceLine,
      isSelected: isRowSelected,
    );
  }
}
