// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../../shared/primitives/graph.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/profiler_utils.dart';
import '../../cpu_profile_model.dart';

/// Represents a graph node for a method in a CPU profile method table.
class MethodTableGraphNode extends GraphNode {
  MethodTableGraphNode({
    required this.name,
    required this.packageUri,
    required this.profileMetaData,
  });

  factory MethodTableGraphNode.fromStackFrame(CpuStackFrame frame) {
    return MethodTableGraphNode(
      name: frame.name,
      packageUri: frame.packageUri,
      profileMetaData: frame.profileMetaData,
    );
  }

  final String name;

  final String packageUri;

  final ProfileMetaData profileMetaData;

  String get id => '$name-$packageUri';

  String get display => '$name ($packageUri)';

  // TODO(kenz): implement the calculation for exclusive and inclusive count.

  /// The number of cpu samples where this frame is on top of the stack.
  ///
  /// This count is used to calculate self time.
  int exclusiveSampleCount = 0;

  /// The number of cpu samples where this frame is anywhere on the stack.
  ///
  /// This count is used to calculate total time.
  int inclusiveSampleCount = 0;

  late double totalTimeRatio =
      safeDivide(inclusiveSampleCount, profileMetaData.sampleCount);

  late Duration totalTime = Duration(
    microseconds:
        (totalTimeRatio * profileMetaData.time!.duration.inMicroseconds)
            .round(),
  );

  late double selfTimeRatio =
      safeDivide(exclusiveSampleCount, profileMetaData.sampleCount);

  late Duration selfTime = Duration(
    microseconds:
        (selfTimeRatio * profileMetaData.time!.duration.inMicroseconds).round(),
  );

  double get inclusiveSampleRatio => safeDivide(
        inclusiveSampleCount,
        profileMetaData.sampleCount,
      );

  double get exclusiveSampleRatio => safeDivide(
        exclusiveSampleCount,
        profileMetaData.sampleCount,
      );
}
