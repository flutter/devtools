// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/widgets.dart';

import '../../shared/console/eval/inspector_tree_v2.dart';
import '../../shared/diagnostics/diagnostics_node.dart';
import 'inspector_controller.dart';
import 'layout_explorer/box/box.dart';
import 'layout_explorer/flex/flex.dart';
import 'widget_properties/properties_view.dart';

/// Panes showing details pertaining to the selected widget.
///
/// Includes both the [FlexLayoutExplorerWidget] or [BoxLayoutExplorerWidget]
/// and the [PropertiesView].
class WidgetDetails extends StatefulWidget {
  const WidgetDetails({super.key, required this.controller});

  final InspectorController controller;

  @override
  State<WidgetDetails> createState() => _WidgetDetailsState();
}

class _WidgetDetailsState extends State<WidgetDetails> with AutoDisposeMixin {
  InspectorController get controller => widget.controller;

  RemoteDiagnosticsNode? get selectedNode =>
      controller.selectedNode.value?.diagnostic;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InspectorTreeNode?>(
      valueListenable: controller.selectedNode,
      builder: (context, _, _) {
        final node = selectedNode;
        if (node == null) {
          return const RoundedOutlinedBorder(
            child: Center(
              child: Text(
                'Select a widget to view its layout and properties.',
                textAlign: TextAlign.center,
                overflow: TextOverflow.clip,
              ),
            ),
          );
        }

        return DetailsTable(controller: controller, node: node);
      },
    );
  }
}
