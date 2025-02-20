// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import '../../shared/analytics/metrics.dart';
import '../../shared/console/primitives/simple_items.dart';
import '../../shared/framework/screen_controllers.dart';
import '../inspector/inspector_controller.dart' as legacy;
import '../inspector/inspector_tree_controller.dart' as legacy;
import '../inspector_v2/inspector_controller.dart' as v2;
import '../inspector_v2/inspector_tree_controller.dart' as v2;

class InspectorScreenController extends DevToolsScreenController {
  InspectorScreenController() {
    _init();
  }

  late v2.InspectorController v2InspectorController;
  late v2.InspectorTreeController v2InspectorTreeController;

  late legacy.InspectorController legacyInspectorController;
  late legacy.InspectorTreeController legacyInspectorTreeController;
  late legacy.InspectorTreeController legacyDetailsTreeController;

  void _init() {
    v2InspectorTreeController = v2.InspectorTreeController(
      gaId: InspectorScreenMetrics.summaryTreeGaId,
    );
    v2InspectorController = v2.InspectorController(
      inspectorTree: v2InspectorTreeController,
      treeType: FlutterTreeType.widget,
    );

    legacyInspectorTreeController = legacy.InspectorTreeController(
      gaId: InspectorScreenMetrics.summaryTreeGaId,
    );
    legacyDetailsTreeController = legacy.InspectorTreeController(
      gaId: InspectorScreenMetrics.detailsTreeGaId,
    );
    legacyInspectorController = legacy.InspectorController(
      inspectorTree: legacyInspectorTreeController,
      detailsTree: legacyDetailsTreeController,
      treeType: FlutterTreeType.widget,
    );
  }

  @override
  void dispose() {
    v2InspectorTreeController.dispose();
    v2InspectorController.dispose();

    legacyInspectorTreeController.dispose();
    legacyDetailsTreeController.dispose();
    legacyInspectorController.dispose();
    super.dispose();
  }
}
