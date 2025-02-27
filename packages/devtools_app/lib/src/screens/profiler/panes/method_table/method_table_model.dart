// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart';

import '../../../../shared/primitives/graph.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/ui/search.dart';
import '../../../../shared/utils/profiler_utils.dart';
import '../../cpu_profile_model.dart';

/// Represents a graph node for a method in a CPU profile method table.
class MethodTableGraphNode extends GraphNode with SearchableDataMixin {
  MethodTableGraphNode({
    required this.name,
    required this.packageUri,
    required this.sourceLine,
    required int totalCount,
    required int selfCount,
    required this.profileMetaData,
    required this.stackFrameIds,
  }) : _totalCount = totalCount,
       _selfCount = selfCount,
       _sourceUri = uriWithSourceLine(packageUri, sourceLine);

  factory MethodTableGraphNode.fromStackFrame(CpuStackFrame frame) {
    return MethodTableGraphNode(
      name: frame.name,
      packageUri: frame.packageUri,
      sourceLine: frame.sourceLine,
      totalCount: frame.inclusiveSampleCount,
      selfCount: frame.exclusiveSampleCount,
      profileMetaData: frame.profileMetaData,
      stackFrameIds: {frame.id},
    );
  }

  final String name;

  final String packageUri;

  final int? sourceLine;

  final String _sourceUri;

  final ProfileMetaData profileMetaData;

  /// The set of all [CpuStackFrame.id]s that contribute to this method table
  /// node for a profile.
  final Set<String> stackFrameIds;

  String get id => '$name-$_sourceUri';

  String get display =>
      '$name${_sourceUri.isNotEmpty ? ' - ($_sourceUri)' : ''}';

  /// The number of cpu samples where this method is on top of the stack.
  int get selfCount => _selfCount;
  late int _selfCount;

  /// The number of cpu samples where this method is anywhere on the stack.
  int get totalCount => _totalCount;
  late int _totalCount;

  double get selfTimeRatio =>
      safeDivide(selfCount, profileMetaData.sampleCount);

  Duration get selfTime => Duration(
    microseconds:
        (selfTimeRatio * profileMetaData.measuredDuration.inMicroseconds)
            .round(),
  );

  double get totalTimeRatio =>
      safeDivide(totalCount, profileMetaData.sampleCount);

  Duration get totalTime => Duration(
    microseconds:
        (totalTimeRatio * profileMetaData.measuredDuration.inMicroseconds)
            .round(),
  );

  void merge(MethodTableGraphNode other, {required bool mergeTotalTime}) {
    if (!shallowEquals(other)) return;
    stackFrameIds.addAll(other.stackFrameIds);
    _selfCount += other.selfCount;
    if (mergeTotalTime) {
      _totalCount += other.totalCount;
    }
  }

  bool shallowEquals(Object? other) {
    return other is MethodTableGraphNode &&
        other.name == name &&
        other._sourceUri == _sourceUri;
  }

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return name.caseInsensitiveContains(regExpSearch) ||
        packageUri.caseInsensitiveContains(regExpSearch);
  }

  @override
  String toString() {
    String generateDisplayFor(
      Set<GraphNode> nodes, {
      required double Function(MethodTableGraphNode) percentCallback,
    }) {
      const newLineAndIndent = '\n    ';
      return nodes
          .cast<MethodTableGraphNode>()
          // Sort in descending order.
          .sorted((a, b) => percentCallback(b).compareTo(percentCallback(a)))
          .map((node) => '${node.display} - ${percent(percentCallback(node))}')
          .join(newLineAndIndent);
    }

    final callers = generateDisplayFor(
      predecessors,
      percentCallback: predecessorEdgePercentage,
    );

    final callees = generateDisplayFor(
      successors,
      percentCallback: successorEdgePercentage,
    );

    return '''
$display ($totalCount samples)
  Callers:
    ${callers.isEmpty ? '[]' : callers}
  Callees:
    ${callees.isEmpty ? '[]' : callees}
''';
  }

  MethodTableGraphNode copy() {
    return MethodTableGraphNode(
      name: name,
      packageUri: packageUri,
      sourceLine: sourceLine,
      totalCount: totalCount,
      selfCount: selfCount,
      profileMetaData: profileMetaData,
      stackFrameIds: Set.of(stackFrameIds),
    );
  }
}

extension MethodTableExtension on CpuStackFrame {
  String get methodTableId => '$name-$packageUriWithSourceLine';
}
