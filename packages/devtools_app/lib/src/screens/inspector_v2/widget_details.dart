// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/widgets.dart';

import '../../shared/console/eval/inspector_tree_v2.dart';
import '../../shared/diagnostics/diagnostics_node.dart';
import '../../shared/ui/tab.dart';
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

  static const layoutExplorerHeight = 150.0;
  static const layoutExplorerWidth = 200.0;

  @override
  State<WidgetDetails> createState() => _WidgetDetailsState();
}

class _WidgetDetailsState extends State<WidgetDetails> with AutoDisposeMixin {
  InspectorController get controller => widget.controller;

  RemoteDiagnosticsNode? get selectedNode =>
      controller.selectedNode.value?.diagnostic;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentHeight = constraints.maxHeight;
        final parentWidth = constraints.maxWidth;
        final horizontalLayout = parentWidth >= (parentHeight * 1.25);
        final canFitLayoutExplorerVertically =
            parentHeight >= WidgetDetails.layoutExplorerHeight;
        final canFitLayoutExplorerHorizontally =
            parentWidth >= WidgetDetails.layoutExplorerWidth;
        final canFitLayoutExplorer =
            canFitLayoutExplorerVertically && canFitLayoutExplorerHorizontally;
        final canFitLargeDetailsTable = horizontalLayout
            ? parentWidth > WidgetDetails.layoutExplorerWidth * 3
            : parentHeight > WidgetDetails.layoutExplorerHeight * 3;

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
                if (BoxLayoutExplorerWidget.shouldDisplay(node) &&
                    canFitLayoutExplorer) ...[
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: horizontalLayout ? densePadding : defaultSpacing,
                          right: horizontalLayout ? defaultSpacing : 0.0,
                          bottom: horizontalLayout ? 0.0 : defaultSpacing,
                        ),
                        child: SizedBox(
                          height: 150.0,
                          width: 200.0,
                          child: BoxLayoutExplorerWidget(controller),
                        ),
                      ),
                    ),
                  ),
                ],
                Expanded(
                  flex: canFitLargeDetailsTable ? 2 : 1,
                  child: DetailsTable(
                    controller: controller,
                    node: node,
                    extraTabs: [
                      if (FlexLayoutExplorerWidget.shouldDisplay(node))
                        (
                          tab: DevToolsTab.create(
                            tabName: 'Flex explorer',
                            gaPrefix: DetailsTable.gaPrefix,
                          ),
                          tabView: FlexLayoutExplorerWidget(controller),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
