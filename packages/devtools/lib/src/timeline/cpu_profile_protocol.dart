// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:meta/meta.dart';

import '../utils.dart';
import 'cpu_profile_model.dart';

/// Protocol for processing [CpuProfileData] and composing it into a structured
/// tree of [CpuStackFrame]'s.
class CpuProfileProtocol {
  void processData(CpuProfileData cpuProfileData) {
    // Do not process this data if it has already been processed.
    if (cpuProfileData.processed) return;

    cpuProfileData.stackFramesJson.forEach((k, v) {
      final stackFrame = CpuStackFrame(
        id: k,
        name: getSimpleStackFrameName(v[CpuProfileData.nameKey]),
        category: v[CpuProfileData.categoryKey],
        // If the user is on a version of Flutter where resolvedUrl is not
        // included in the response, this will be null. If the frame is a native
        // frame, the this will be the empty string.
        url: v[CpuProfileData.resolvedUrlKey],
      );
      _processStackFrame(
        stackFrame,
        cpuProfileData.stackFrames[v[CpuProfileData.parentIdKey]],
        cpuProfileData,
      );
    });
    _setExclusiveSampleCounts(cpuProfileData);

    cpuProfileData.processed = true;

    assert(
      cpuProfileData.sampleCount ==
          cpuProfileData.cpuProfileRoot.inclusiveSampleCount,
      'SampleCount from response (${cpuProfileData.sampleCount})'
      ' != sample count from root '
      '(${cpuProfileData.cpuProfileRoot.inclusiveSampleCount})',
    );
  }

  void _processStackFrame(
    CpuStackFrame stackFrame,
    CpuStackFrame parent,
    CpuProfileData cpuProfileData,
  ) {
    cpuProfileData.stackFrames[stackFrame.id] = stackFrame;

    if (parent == null) {
      // [stackFrame] is the root of a new cpu sample. Add it as a child of
      // [cpuProfile].
      cpuProfileData.cpuProfileRoot.addChild(stackFrame);
    } else {
      parent.addChild(stackFrame);
    }
  }

  void _setExclusiveSampleCounts(CpuProfileData cpuProfileData) {
    for (Map<String, dynamic> traceEvent in cpuProfileData.stackTraceEvents) {
      final leafId = traceEvent[CpuProfileData.stackFrameIdKey];
      assert(
        cpuProfileData.stackFrames[leafId] != null,
        'No StackFrame found for id $leafId. If you see this assertion, please '
        'export the timeline trace and send to kenzieschmoll@google.com. Note: '
        'you must export the timeline immediately after the AssertionError is '
        'thrown.',
      );
      cpuProfileData.stackFrames[leafId]?.exclusiveSampleCount++;
    }
  }

  /// Returns a simplified version of a StackFrame name.
  ///
  /// Given an input such as
  /// "_WidgetsFlutterBinding&BindingBase&GestureBinding.handleBeginFrame", this
  /// method will strip off all the Mixin names and return
  /// "_WidgetsFlutterBinding.handleBeginFrame".
  @visibleForTesting
  String getSimpleStackFrameName(String name) {
    final firstAmpersandIndex = name.indexOf('&');
    final firstPeriodIndex = name.indexOf('.');

    if (firstAmpersandIndex != -1 &&
        firstPeriodIndex != -1 &&
        firstAmpersandIndex < firstPeriodIndex &&
        name.length > firstAmpersandIndex + 1) {
      final nextCharCodeUnit = name[firstAmpersandIndex + 1].codeUnitAt(0);
      if (isLetter(nextCharCodeUnit)) {
        return name.substring(0, firstAmpersandIndex) +
            name.substring(firstPeriodIndex);
      }
    }

    return name;
  }
}
