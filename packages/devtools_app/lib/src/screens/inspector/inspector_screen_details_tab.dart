// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/preferences.dart';
import '../../shared/primitives/blocking_action_mixin.dart';
import '../../shared/ui/tab.dart';
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
      (
        tab: _buildTab(tabName: InspectorDetailsViewType.layoutExplorer.key),
        tabView: LayoutExplorerTab(controller: controller),
      ),
      (
        tab: _buildTab(
          tabName: InspectorDetailsViewType.widgetDetailsView.key,
          trailing: InspectorExpandCollapseButtons(controller: controller),
        ),
        tabView: detailsTree,
      ),
    ];
    return ValueListenableBuilder(
      valueListenable: preferences.inspector.defaultDetailsView,
      builder: (BuildContext context, value, Widget? child) {
        int defaultInspectorViewIndex = 0;

        if (preferences.inspector.defaultDetailsView.value ==
            InspectorDetailsViewType.widgetDetailsView) {
          defaultInspectorViewIndex = 1;
        }

        return AnalyticsTabbedView(
          tabs: tabs,
          gaScreen: gac.inspector,
          initialSelectedIndex: defaultInspectorViewIndex,
        );
      },
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
  bool get enableButtons => !actionInProgress;

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
            child: GaDevToolsButton(
              icon: Icons.unfold_more,
              onPressed: enableButtons ? _onExpandClick : null,
              label: 'Expand all',
              minScreenWidthForTextBeforeScaling:
                  InspectorScreenBodyState.minScreenWidthForTextBeforeScaling,
              gaScreen: gac.inspector,
              gaSelection: gac.expandAll,
              outlined: false,
            ),
          ),
          const SizedBox(width: denseSpacing),
          SizedBox(
            child: GaDevToolsButton(
              icon: Icons.unfold_less,
              onPressed: enableButtons ? _onCollapseClick : null,
              label: 'Collapse to selected',
              minScreenWidthForTextBeforeScaling:
                  InspectorScreenBodyState.minScreenWidthForTextBeforeScaling,
              gaScreen: gac.inspector,
              gaSelection: gac.collapseAll,
              outlined: false,
            ),
          ),
        ],
      ),
    );
  }

  void _onExpandClick() {
    unawaited(
      blockWhileInProgress(() async {
        ga.select(gac.inspector, gac.expandAll);
        await widget.controller.expandAllNodesInDetailsTree();
      }),
    );
  }

  void _onCollapseClick() {
    ga.select(
      gac.inspector,
      gac.collapseAll,
    );
    widget.controller.collapseDetailsToSelected();
  }
}
