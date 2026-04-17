// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import '../../shared/analytics/metrics.dart';
import '../../shared/console/primitives/simple_items.dart';
import '../../shared/framework/screen.dart';
import '../../shared/framework/screen_controllers.dart';
import '../inspector/inspector_controller.dart';
import '../inspector/inspector_tree_controller.dart';

/// Screen controller for the Inspector screen.
///
/// This controller can be accessed from anywhere in DevTools, as long as it was
/// first registered, by
/// calling `screenControllers.lookup<InspectorScreenController>()`.
///
/// The controller lifecycle is managed by the [ScreenControllers] class. The
/// `init` method is called lazily upon the first controller access from
/// `screenControllers`. The `dispose` method is called by `screenControllers`
/// when DevTools is destroying a set of DevTools screen controllers.
class InspectorScreenController extends DevToolsScreenController {
  @override
  final screenId = ScreenMetaData.inspector.id;

  late InspectorController inspectorController;
  late InspectorTreeController inspectorTreeController;

  @override
  void init() {
    super.init();
    inspectorTreeController = InspectorTreeController(
      gaId: InspectorScreenMetrics.summaryTreeGaId,
    );
    inspectorController = InspectorController(
      inspectorTree: inspectorTreeController,
      treeType: FlutterTreeType.widget,
    );
  }

  @override
  void dispose() {
    inspectorTreeController.dispose();
    inspectorController.dispose();
    super.dispose();
  }
}
