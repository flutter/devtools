import 'package:flutter/foundation.dart';

import '../../../../shared/primitives/utils.dart';
import '../../../../shared/profiler_utils.dart';
import '../../cpu_profile_model.dart';
import 'method_table_model.dart';

class MethodTableController {
  final selectedNode = ValueNotifier<MethodTableGraphNode?>(null);

  final methods = ValueNotifier<List<MethodTableGraphNode>>([]);

  void createMethodTableForProfile(CpuProfileData cpuProfileData) {
    // TODO(kenz): generate the method table graph.
  }

  double callerPercentageFor(MethodTableGraphNode node) {
    return selectedNode.value?.predecessorEdgePercentage(node) ?? 0.0;
  }

  double calleePercentageFor(MethodTableGraphNode node) {
    return selectedNode.value?.successorEdgePercentage(node) ?? 0.0;
  }

  void reset() {
    selectedNode.value = null;
    methods.value = <MethodTableGraphNode>[];
  }
}
