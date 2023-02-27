// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../../../shared/primitives/utils.dart';
import '../../cpu_profile_model.dart';
import 'method_table_model.dart';

/// Controller for the CPU profile method table.
///
/// This controller is responsible for managing state of the Method table UI
/// and for providing utility methods to interact with the active data.
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
