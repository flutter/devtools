// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/routing.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/utils.dart';
import '../debugger/codeview_controller.dart';
import '../debugger/debugger_screen.dart';
import '../vm_developer/vm_developer_common_widgets.dart';
import 'cpu_profile_model.dart';

const timeColumnWidthPx = 180.0;

class SelfTimeColumn extends ColumnData<CpuStackFrame> {
  SelfTimeColumn({String? titleTooltip})
      : super(
          'Self Time',
          titleTooltip: titleTooltip,
          fixedWidthPx: scaleByFontFactor(timeColumnWidthPx),
        );

  @override
  bool get numeric => true;

  @override
  int compare(CpuStackFrame a, CpuStackFrame b) {
    final int result = super.compare(a, b);
    if (result == 0) {
      return a.name.compareTo(b.name);
    }
    return result;
  }

  @override
  int getValue(CpuStackFrame dataObject) => dataObject.selfTime.inMicroseconds;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return '${msText(dataObject.selfTime, fractionDigits: 2)} '
        '(${percent2(dataObject.selfTimeRatio)})';
  }

  @override
  String getTooltip(CpuStackFrame dataObject) => '';
}

class TotalTimeColumn extends ColumnData<CpuStackFrame> {
  TotalTimeColumn({String? titleTooltip})
      : super(
          'Total Time',
          titleTooltip: titleTooltip,
          fixedWidthPx: scaleByFontFactor(timeColumnWidthPx),
        );

  @override
  bool get numeric => true;

  @override
  int compare(CpuStackFrame a, CpuStackFrame b) {
    final int result = super.compare(a, b);
    if (result == 0) {
      return a.name.compareTo(b.name);
    }
    return result;
  }

  @override
  int getValue(CpuStackFrame dataObject) => dataObject.totalTime.inMicroseconds;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return '${msText(dataObject.totalTime, fractionDigits: 2)} '
        '(${percent2(dataObject.totalTimeRatio)})';
  }

  @override
  String getTooltip(CpuStackFrame dataObject) => '';
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
