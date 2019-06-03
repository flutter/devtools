// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:convert';
import 'dart:math';

import 'package:meta/meta.dart';

import '../utils.dart';

/// Data model for DevTools CPU profile.
class CpuProfileData {
  CpuProfileData._({
    @required this.stackFramesJson,
    @required this.stackTraceEvents,
    @required this.sampleCount,
    @required this.samplePeriod,
    @required this.time,
  });

  static CpuProfileData parse(Map<String, dynamic> json) {
    return CpuProfileData._(
      stackFramesJson: jsonDecode(jsonEncode(json[stackFramesKey] ?? {})),
      stackTraceEvents:
          (json[traceEventsKey] ?? []).cast<Map<String, dynamic>>(),
      sampleCount: json[sampleCountKey],
      samplePeriod: json[samplePeriodKey],
      time: (json[timeOriginKey] != null && json[timeExtentKey] != null)
          ? (TimeRange()
            ..start = Duration(microseconds: json[timeOriginKey])
            ..end = Duration(
                microseconds: json[timeOriginKey] + json[timeExtentKey]))
          : null,
    );
  }

  // Key fields from the VM response JSON.
  static const nameKey = 'name';
  static const categoryKey = 'category';
  static const parentIdKey = 'parent';
  static const stackFrameIdKey = 'sf';
  static const resolvedUrlKey = 'resolvedUrl';
  static const stackFramesKey = 'stackFrames';
  static const traceEventsKey = 'traceEvents';
  static const sampleCountKey = 'sampleCount';
  static const samplePeriodKey = 'samplePeriod';
  static const timeOriginKey = 'timeOriginMicros';
  static const timeExtentKey = 'timeExtentMicros';

  /// Marks whether this data has already been processed.
  bool processed = false;

  final Map<String, dynamic> stackFramesJson;

  /// Trace events associated with the last stackFrame in each sample (i.e. the
  /// leaves of the [CpuStackFrame] objects).
  ///
  /// The trace event will contain a field 'sf' that contains the id of the leaf
  /// stack frame.
  final List<Map<String, dynamic>> stackTraceEvents;

  final int sampleCount;

  final int samplePeriod;

  final TimeRange time;

  final cpuProfileRoot = CpuStackFrame(
    id: 'cpuProfile',
    name: 'all',
    category: 'Dart',
    url: 'root',
  );

  Map<String, CpuStackFrame> stackFrames = {};

  Map<String, dynamic> get json => {
        'type': '_CpuProfileTimeline',
        samplePeriodKey: samplePeriod,
        sampleCountKey: sampleCount,
        timeOriginKey: time.start.inMicroseconds,
        timeExtentKey: time.duration.inMicroseconds,
        stackFramesKey: stackFramesJson,
        traceEventsKey: stackTraceEvents,
      };
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

  final List<CpuStackFrame> children = [];

  CpuStackFrame parent;

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
      _inclusiveSampleCount ?? _calculateInclusiveSampleCount();

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
  int _calculateInclusiveSampleCount() {
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
