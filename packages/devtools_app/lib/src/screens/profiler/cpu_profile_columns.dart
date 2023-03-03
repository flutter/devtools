// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/globals.dart';
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

  static const _separator = ' - ';

  @override
  String getValue(CpuStackFrame dataObject) => dataObject.name;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    if (dataObject.packageUriWithSourceLine.isNotEmpty) {
      return '${dataObject.name}$_separator${_sourceDisplay(dataObject)}';
    }
    return dataObject.name;
  }

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
    final sourceTextSpans = <TextSpan>[];
    if (data.packageUriWithSourceLine.isNotEmpty) {
      sourceTextSpans.add(const TextSpan(text: _separator));

      final script = scriptManager.scriptRefForUri(data.packageUri);
      final showSourceAsLink = script != null;
      if (showSourceAsLink) {
        sourceTextSpans.add(
          VmServiceObjectLink(
            object: script,
            textBuilder: (_) => _sourceDisplay(data),
            isSelected: isRowSelected,
            onTap: (e) {
              DevToolsRouterDelegate.of(context).navigate(
                DebuggerScreen.id,
                const {},
                CodeViewSourceLocationNavigationState(
                  script: script,
                  line: data.sourceLine!,
                ),
              );
            },
          ).buildTextSpan(context),
        );
      } else {
        sourceTextSpans.add(
          TextSpan(
            text: _sourceDisplay(data),
            style: contentTextStyle(
              context,
              data,
              isSelected: isRowSelected,
            ),
          ),
        );
      }
    }
    return Row(
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            text: data.name,
            style: contentTextStyle(
              context,
              data,
              isSelected: isRowSelected,
            ),
            children: sourceTextSpans,
          ),
        ),
        // Include this [Spacer] so that the clickable [VmServiceObjectLink]
        // does not extend all the way to the end of the row.
        const Spacer(),
      ],
    );
  }

  String _sourceDisplay(CpuStackFrame data) =>
      '(${data.packageUriWithSourceLine})';
}
