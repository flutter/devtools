// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../../shared/table/table.dart';
import '../../../shared/table/table_data.dart';
import '../../../shared/utils/profiler_utils.dart';
import '../cpu_profile_model.dart';

class SelfTimeColumn extends TimeAndPercentageColumn<CpuStackFrame> {
  SelfTimeColumn({
    super.titleTooltip,
    RichTooltipBuilder<CpuStackFrame>? dataTooltipProvider,
  }) : super(
         title: 'Self Time',
         timeProvider: (stackFrame) => stackFrame.selfTime,
         percentAsDoubleProvider: (stackFrame) => stackFrame.selfTimeRatio,
         richTooltipProvider: dataTooltipProvider,
         secondaryCompare: (stackFrame) => stackFrame.name,
       );
}

class TotalTimeColumn extends TimeAndPercentageColumn<CpuStackFrame> {
  TotalTimeColumn({
    super.titleTooltip,
    RichTooltipBuilder<CpuStackFrame>? dataTooltipProvider,
  }) : super(
         title: 'Total Time',
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
  String getDisplayValue(CpuStackFrame dataObject) {
    if (dataObject.packageUriWithSourceLine.isNotEmpty) {
      return '${dataObject.name}'
          '${MethodAndSourceDisplay.separator}'
          '(${dataObject.packageUriWithSourceLine})';
    }
    return dataObject.name;
  }

  @override
  Widget? build(
    BuildContext context,
    CpuStackFrame data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return MethodAndSourceDisplay(
      methodName: data.name,
      packageUri: data.packageUri,
      sourceLine: data.sourceLine,
    );
  }
}
