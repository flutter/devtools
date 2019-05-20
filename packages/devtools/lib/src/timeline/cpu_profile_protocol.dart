// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart' show Response;

import '../utils.dart';

class CpuProfileData {
  CpuProfileData(this.cpuProfileResponse, this.duration)
      : sampleCount = cpuProfileResponse.json['sampleCount'],
        samplePeriod = cpuProfileResponse.json['samplePeriod'],
        stackFramesJson = cpuProfileResponse.json['stackFrames'],
        stackTraceEvents = cpuProfileResponse.json['traceEvents'] {
    _processStackFrames(cpuProfileResponse);
    _setExclusiveSampleCounts();

    assert(
      sampleCount == cpuProfileRoot.inclusiveSampleCount,
      'SampleCount from response ($sampleCount) != sample count from root'
      ' (${cpuProfileRoot.inclusiveSampleCount})',
    );
  }

  // Key fields from the response JSON.
  static const name = 'name';
  static const category = 'category';
  static const parentId = 'parent';
  static const stackFrameId = 'sf';
  static const resolvedUrl = 'resolvedUrl';

  final Response cpuProfileResponse;
  final Duration duration;
  final int sampleCount;
  final int samplePeriod;
  final Map<String, dynamic> stackFramesJson;

  /// Trace events associated with the last stackFrame in each sample (i.e. the
  /// leaves of the [CpuStackFrame] objects).
  ///
  /// The trace event will contain a field 'sf' that contains the id of the leaf
  /// stack frame.
  final List<dynamic> stackTraceEvents;

  final cpuProfileRoot = CpuStackFrame(
    id: 'cpuProfile',
    name: 'all',
    category: 'Dart',
    url: 'root',
  );

  Map<String, CpuStackFrame> stackFrames = {};

  void _processStackFrames(Response response) {
    stackFramesJson.forEach((k, v) {
      final stackFrame = CpuStackFrame(
        id: k,
        name: v[name],
        category: v[category],
        // If the user is on a version of Flutter where resolvedUrl is not
        // included in the response, this will be null. If the frame is a native
        // frame, the this will be the empty string.
        url: v[resolvedUrl],
      );
      _processStackFrame(stackFrame, stackFrames[v[parentId]]);
    });
  }

  void _processStackFrame(CpuStackFrame stackFrame, CpuStackFrame parent) {
    stackFrames[stackFrame.id] = stackFrame;

    if (parent == null) {
      // [stackFrame] is the root of a new cpu sample. Add it as a child of
      // [cpuProfile].
      cpuProfileRoot.addChild(stackFrame);
    } else {
      parent.addChild(stackFrame);
    }
  }

  void _setExclusiveSampleCounts() {
    for (Map<String, dynamic> traceEvent in stackTraceEvents) {
      final leafId = traceEvent[stackFrameId];
      assert(
        stackFrames[leafId] != null,
        'No StackFrame found for id $leafId. If you see this assertion, please '
        'export the timeline trace and send to kenzieschmoll@google.com. Note: '
        'you must export the timeline immediately after the AssertionError is '
        'thrown.',
      );
      stackFrames[leafId]?.exclusiveSampleCount++;
    }
  }
}

class CpuStackFrame {
  CpuStackFrame({
    @required this.id,
    @required this.name,
    @required this.category,
    @required this.url,
  });

  final String id;
  final String name;
  final String category;
  final String url;

  CpuStackFrame parent;
  List<CpuStackFrame> children = [];

  /// Index in [parent.children].
  int index = -1;

  /// How many cpu samples for which this frame is a leaf.
  int exclusiveSampleCount = 0;

  /// Depth of this CpuStackFrame tree, including [this].
  ///
  /// We assume that CpuStackFrame nodes are not modified after the first time
  /// [depth] is accessed. We would need to clear the cache if this was
  /// supported.
  int get depth {
    if (_depth != 0) {
      return _depth;
    }
    for (CpuStackFrame child in children) {
      _depth = max(_depth, child.depth);
    }
    return _depth = _depth + 1;
  }

  int _depth = 0;

  int get inclusiveSampleCount =>
      _inclusiveSampleCount ?? calculateInclusiveSampleCount();

  /// How many cpu samples this frame is included in.
  int _inclusiveSampleCount;

  double get cpuConsumptionRatio => _cpuConsumptionRatio ??=
      inclusiveSampleCount / getRoot().inclusiveSampleCount;

  double _cpuConsumptionRatio;

  void addChild(CpuStackFrame child) {
    children.add(child);
    child.parent = this;
    child.index = children.length - 1;
  }

  CpuStackFrame getRoot() {
    CpuStackFrame root = this;
    while (root.parent != null) {
      root = root.parent;
    }
    return root;
  }

  /// Returns the number of cpu samples this stack frame is a part of.
  ///
  /// This will be equal to the number of leaf nodes under this stack frame.
  int calculateInclusiveSampleCount() {
    int count = exclusiveSampleCount;
    for (CpuStackFrame child in children) {
      count += child.inclusiveSampleCount;
    }
    _inclusiveSampleCount = count;
    return _inclusiveSampleCount;
  }

  void _format(StringBuffer buf, String indent) {
    buf.writeln(
        '$indent$id - children: ${children.length} - exclusiveSampleCount: '
        '$exclusiveSampleCount');
    for (CpuStackFrame child in children) {
      child._format(buf, '  $indent');
    }
  }

  @visibleForTesting
  String toStringDeep() {
    final buf = StringBuffer();
    _format(buf, '  ');
    return buf.toString();
  }

  @override
  String toString({Duration duration}) {
    final buf = StringBuffer();
    buf.write('$name ');
    if (duration != null) {
      // TODO(kenzie): use a number of fractionDigits that better matches the
      // resolution of the stack frame.
      buf.write('- ${msText(duration, fractionDigits: 2)} ');
    }
    buf.write('($inclusiveSampleCount ');
    buf.write(inclusiveSampleCount == 1 ? 'sample' : 'samples');
    buf.write(', ${percent2(cpuConsumptionRatio)})');
    return buf.toString();
  }
}
