// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/widgets.dart';

import '../../shared/console/eval/inspector_tree_v2.dart';
import '../../shared/diagnostics/diagnostics_node.dart';
import 'inspector_controller.dart';
import 'inspector_screen.dart';
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
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalLayout = isScreenWiderThan(context, screenHeight);

    return ValueListenableBuilder<InspectorTreeNode?>(
      valueListenable: controller.selectedNode,
      builder: (context, _, __) {
        final node = selectedNode;
        if (node == null) {
          return const Center(
            child: Text(
              'Select a widget to view its layout.',
              textAlign: TextAlign.center,
              overflow: TextOverflow.clip,
            ),
          );
        }

        return Flex(
          direction: horizontalLayout ? Axis.horizontal : Axis.vertical,
          children: [
            if (BoxLayoutExplorerWidget.shouldDisplay(node)) ...[
              Padding(
                padding: horizontalLayout
                    ? const EdgeInsets.only(
                        top: denseSpacing,
                        right: defaultSpacing,
                      )
                    : const EdgeInsets.only(
                        top: denseSpacing,
                        bottom: defaultSpacing,
                      ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: 150.0,
                    width: 200.0,
                    child: BoxLayoutExplorerWidget(controller),
                  ),
                ),
              ),
            ],
            Expanded(
              child: PropertiesView(controller: controller, node: node),
            ),
          ],
        );
      },
    );
  }
}
