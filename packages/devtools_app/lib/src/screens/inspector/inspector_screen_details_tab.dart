// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../primitives/blocking_action_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/theme.dart';
import '../../ui/tab.dart';
import 'inspector_controller.dart';
import 'inspector_screen.dart';
import 'layout_explorer/layout_explorer.dart';

class InspectorDetails extends StatelessWidget {
  const InspectorDetails({
    required this.detailsTree,
    required this.controller,
    Key? key,
  }) : super(key: key);

  final Widget detailsTree;
  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildTab(tabName: 'Layout Explorer'),
      _buildTab(
        tabName: 'Widget Details Tree',
        trailing: InspectorExpandCollapseButtons(controller: controller),
      ),
    ];
    final tabViews = <Widget>[
      LayoutExplorerTab(controller: controller),
      detailsTree,
    ];

    return AnalyticsTabbedView(
      tabs: tabs,
      tabViews: tabViews,
      gaScreen: analytics_constants.inspector,
    );
  }

  DevToolsTab _buildTab({required String tabName, Widget? trailing}) {
    return DevToolsTab.create(
      tabName: tabName,
      gaPrefix: 'inspectorDetailsTab',
      trailing: trailing,
    );
  }
}

class InspectorExpandCollapseButtons extends StatefulWidget {
  const InspectorExpandCollapseButtons({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final InspectorController controller;

  @override
  State<InspectorExpandCollapseButtons> createState() =>
      _InspectorExpandCollapseButtonsState();
}

class _InspectorExpandCollapseButtonsState
    extends State<InspectorExpandCollapseButtons> with BlockingActionMixin {
  bool get enableButtons => actionInProgress == false;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        border: Border(
          left: defaultBorderSide(Theme.of(context)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            child: IconLabelButton(
              icon: Icons.unfold_more,
              onPressed: enableButtons ? _onExpandClick : null,
              label: 'Expand all',
              minScreenWidthForTextBeforeScaling:
                  InspectorScreenBodyState.minScreenWidthForTextBeforeScaling,
              outlined: false,
            ),
          ),
          const SizedBox(width: denseSpacing),
          SizedBox(
            child: IconLabelButton(
              icon: Icons.unfold_less,
              onPressed: enableButtons ? _onCollapseClick : null,
              label: 'Collapse to selected',
              minScreenWidthForTextBeforeScaling:
                  InspectorScreenBodyState.minScreenWidthForTextBeforeScaling,
              outlined: false,
            ),
          )
        ],
      ),
    );
  }

  void _onExpandClick() {
    blockWhileInProgress(() async {
      ga.select(analytics_constants.inspector, analytics_constants.expandAll);
      await widget.controller.expandAllNodesInDetailsTree();
    });
  }

  void _onCollapseClick() {
    blockWhileInProgress(() async {
      ga.select(analytics_constants.inspector, analytics_constants.collapseAll);
      await widget.controller.collapseDetailsToSelected();
    });
  }
}
