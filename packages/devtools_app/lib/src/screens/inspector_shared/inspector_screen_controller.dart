// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/utils.dart';

import '../../shared/analytics/metrics.dart';
import '../../shared/console/primitives/simple_items.dart';
import '../inspector/inspector_controller.dart' as legacy;
import '../inspector/inspector_tree_controller.dart' as legacy;
import '../inspector_v2/inspector_controller.dart' as v2;
import '../inspector_v2/inspector_tree_controller.dart' as v2;

class InspectorScreenController extends DisposableController {
  @override
  void dispose() {
    v2InspectorController.dispose();
    legacyInspectorController.dispose();
    super.dispose();
  }

  final v2InspectorController = v2.InspectorController(
    inspectorTree: v2.InspectorTreeController(
      gaId: InspectorScreenMetrics.summaryTreeGaId,
    ),
    treeType: FlutterTreeType.widget,
  );

  final legacyInspectorController = legacy.InspectorController(
    inspectorTree: legacy.InspectorTreeController(
      gaId: InspectorScreenMetrics.summaryTreeGaId,
    ),
    detailsTree: legacy.InspectorTreeController(
      gaId: InspectorScreenMetrics.detailsTreeGaId,
    ),
    treeType: FlutterTreeType.widget,
  );
}
