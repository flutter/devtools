// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../../shared/primitives/trees.dart';
import '../../../../shared/primitives/utils.dart';
import '../../../../shared/ui/search.dart';
import '../../cpu_profile_model.dart';
import '../../cpu_profiler_controller.dart';
import 'method_table_model.dart';

/// Controller for the CPU profile method table.
///
/// This controller is responsible for managing state of the Method table UI
/// and for providing utility methods to interact with the active data.
class MethodTableController extends DisposableController
    with
        SearchControllerMixin<MethodTableGraphNode>,
        AutoDisposeControllerMixin {
  MethodTableController({
    required ValueListenable<CpuProfileData?> dataNotifier,
  }) {
    createMethodTableGraph(dataNotifier.value);
    addAutoDisposeListener(dataNotifier, () {
      createMethodTableGraph(dataNotifier.value);
    });
  }

  final selectedNode = ValueNotifier<MethodTableGraphNode?>(null);

  ValueListenable<List<MethodTableGraphNode>> get methods => _methods;

  final _methods = ValueNotifier<List<MethodTableGraphNode>>([]);

  void _setData(List<MethodTableGraphNode> data) {
    _methods.value = data;
    refreshSearchMatches();
  }

  @visibleForTesting
  void createMethodTableGraph(CpuProfileData? cpuProfileData) {
    reset();
    if (cpuProfileData == null ||
        cpuProfileData == CpuProfilerController.baseStateCpuProfileData ||
        cpuProfileData == CpuProfilerController.emptyAppStartUpProfile ||
        !cpuProfileData.processed) {
      return;
    }

    List<CpuStackFrame> profileRoots = cpuProfileData.callTreeRoots;
    // For a profile rooted at tags, treat it as if it is not. Otherwise, the
    // tags will show up in the method table.
    if (cpuProfileData.rootedAtTags) {
      profileRoots = [];
      for (final tagRoot in cpuProfileData.callTreeRoots) {
        profileRoots.addAll(tagRoot.children);
      }
    }

    final methodMap = <String, MethodTableGraphNode>{};
    for (final root in profileRoots) {
      depthFirstTraversal(
        root,
        action: (CpuStackFrame frame) {
          final parentNode = frame.parent != null &&
                  frame.parentId != CpuProfileData.rootId &&
                  !frame.parent!.isTag
              // Since we are performing a DFS, the parent should always be in
              // the map.
              ? methodMap[frame.parent!.methodTableId]!
              : null;

          var graphNode = MethodTableGraphNode.fromStackFrame(frame);
          final existingNode = methodMap[frame.methodTableId];
          if (existingNode != null) {
            // Do not merge the total time if the [existingNode] already counted
            // the total time for one of [frame]'s ancestors.
            final shouldMergeTotalTime =
                !existingNode.stackFrameIds.containsAny(frame.ancestorIds);
            // If the graph node already exists, merge the new one with the old
            // one and use the existing instance.
            existingNode.merge(graphNode, mergeTotalTime: shouldMergeTotalTime);
            graphNode = existingNode;
          }
          methodMap[graphNode.id] = graphNode;

          parentNode?.outgoingEdge(
            graphNode,
            edgeWeight: frame.inclusiveSampleCount,
          );
        },
      );
    }
    _setData(methodMap.values.toList());
  }

  double callerPercentageFor(MethodTableGraphNode node) {
    return selectedNode.value?.predecessorEdgePercentage(node) ?? 0.0;
  }

  double calleePercentageFor(MethodTableGraphNode node) {
    return selectedNode.value?.successorEdgePercentage(node) ?? 0.0;
  }

  void reset({bool shouldResetSearch = false}) {
    selectedNode.value = null;
    if (shouldResetSearch) {
      resetSearch();
    }
    _setData([]);
  }

  @visibleForTesting
  String graphAsString() {
    methods.value.sort((m1, m2) => m2.totalCount.compareTo(m1.totalCount));
    return methods.value.map((node) => node.toString()).toList().join('\n');
  }

  @override
  Iterable<MethodTableGraphNode> get currentDataToSearchThrough =>
      methods.value;
}
