// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';

import '../../shared/analytics/metrics.dart';
import '../../shared/console/primitives/simple_items.dart';
import '../inspector/inspector_controller.dart' as legacy;
import '../inspector/inspector_tree_controller.dart' as legacy;
import '../inspector_v2/inspector_controller.dart' as v2;
import '../inspector_v2/inspector_tree_controller.dart' as v2;

class InspectorController extends DisposableController {
  InspectorController();

  v2.InspectorController get inspectorControllerV2 => v2.InspectorController(
        inspectorTree: v2.InspectorTreeController(
          gaId: InspectorScreenMetrics.summaryTreeGaId,
        ),
        treeType: FlutterTreeType.widget,
      );

  legacy.InspectorController get inspectorControllerLegacy =>
      legacy.InspectorController(
        inspectorTree: legacy.InspectorTreeController(
          gaId: InspectorScreenMetrics.summaryTreeGaId,
        ),
        detailsTree: legacy.InspectorTreeController(
          gaId: InspectorScreenMetrics.detailsTreeGaId,
        ),
        treeType: FlutterTreeType.widget,
      );
}
