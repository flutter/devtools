// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math';

import 'package:vm_service_lib/vm_service_lib.dart' show Response;

import '../utils.dart';

class CpuProfileData {
  CpuProfileData(this.cpuProfileResponse)
      : sampleCount = cpuProfileResponse.json['sampleCount'],
        samplePeriod = cpuProfileResponse.json['samplePeriod'],
        timeExtentMicros = cpuProfileResponse.json['timeExtentMicros'],
        stackFramesJson = cpuProfileResponse.json['stackFrames'],
        stackTraceEvents = cpuProfileResponse.json['traceEvents'] {
    _processStackFrames(cpuProfileResponse);
  }

  final Response cpuProfileResponse;
  final int sampleCount;
  final int samplePeriod;
  final int timeExtentMicros;
  final Map<String, dynamic> stackFramesJson;

  /// Trace events associated with the last stackFrame in each sample (i.e. the
  /// leaves of the [CpuStackFrame] objects).
  ///
  /// The trace event will contain a field 'sf' that contains the id of the leaf
  /// stack frame.
  final List<dynamic> stackTraceEvents;

  var cpuProfileRoot = CpuStackFrame('cpuProfile', 'all', 'Dart');

  Map<String, CpuStackFrame> stackFrames = {};

  void _processStackFrames(Response response) {
    stackFramesJson.forEach((k, v) {
      final stackFrame = CpuStackFrame(k, v['name'], v['category']);
      final parent = stackFrames[v['parent']];
      _processStackFrame(stackFrame, parent);
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
}

class CpuStackFrame {
  CpuStackFrame(this.id, this.name, this.category);

  final String id;
  final String name;
  final String category;

  CpuStackFrame parent;
  List<CpuStackFrame> children = [];

  /// Index in [parent.children].
  int index = -1;

  bool get isLeaf => children.isEmpty;

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

  int get sampleCount => _sampleCount ?? calculateSampleCount();

  int _sampleCount;

  double get cpuConsumptionRatio =>
      _cpuConsumptionRatio ??= sampleCount / getRoot().sampleCount;

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
  /// This will be equal to the number of leaf nodes in this stack frame.
  int calculateSampleCount() {
    if (isLeaf) {
      _sampleCount = 1;
    } else {
      int count = 0;
      for (CpuStackFrame child in children) {
        count += child.sampleCount;
      }
      _sampleCount = count;
    }
    return _sampleCount;
  }

  void format(StringBuffer buf, String indent) {
    buf.writeln('$indent$id - children: ${children.length}');
    for (CpuStackFrame child in children) {
      child.format(buf, '  $indent');
    }
  }

  String toStringDeep() {
    final buf = StringBuffer();
    format(buf, '  ');
    return buf.toString();
  }

  @override
  String toString() {
    return '$name ($sampleCount samples, '
        '${percent2(cpuConsumptionRatio)})';
  }
}
