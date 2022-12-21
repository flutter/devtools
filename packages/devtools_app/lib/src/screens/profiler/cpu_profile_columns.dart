// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

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
  dynamic getValue(CpuStackFrame dataObject) =>
      dataObject.selfTime.inMicroseconds;

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
  dynamic getValue(CpuStackFrame dataObject) =>
      dataObject.totalTime.inMicroseconds;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return '${msText(dataObject.totalTime, fractionDigits: 2)} '
        '(${percent2(dataObject.totalTimeRatio)})';
  }

  @override
  String getTooltip(CpuStackFrame dataObject) => '';
}

class MethodNameColumn extends TreeColumnData<CpuStackFrame> {
  MethodNameColumn() : super('Method');
  @override
  dynamic getValue(CpuStackFrame dataObject) => dataObject.name;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return dataObject.name;
  }

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(CpuStackFrame dataObject) => dataObject.name;
}

// TODO(kenz): make these urls clickable once we can jump to source.
class SourceColumn extends ColumnData<CpuStackFrame>
    implements ColumnRenderer<CpuStackFrame> {
  SourceColumn() : super.wide('Source', alignment: ColumnAlignment.right);

  @override
  dynamic getValue(CpuStackFrame dataObject) =>
      dataObject.packageUriWithSourceLine;

  @override
  String getDisplayValue(CpuStackFrame dataObject) {
    return dataObject.packageUriWithSourceLine;
  }

  @override
  String getTooltip(CpuStackFrame dataObject) =>
      dataObject.packageUriWithSourceLine;

  @override
  bool get supportsSorting => true;

  @override
  Widget? build(
    BuildContext context,
    CpuStackFrame data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    final script = scriptManager.sortedScripts.value.firstWhereOrNull(
      (element) => element.uri == data.packageUri,
    );
    if (script == null) {
      return null;
    }
    final routerDelegate = DevToolsRouterDelegate.of(context);
    return VmServiceObjectLink<ScriptRef>(
      object: script,
      textBuilder: (_) => getDisplayValue(data),
      onTap: (e) {
        routerDelegate.navigate(
          DebuggerScreen.id,
          const {},
          CodeViewSourceLocationNavigationState(
            script: script,
            line: data.sourceLine!,
          ),
        );
      },
    );
  }
}
