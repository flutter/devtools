// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/primitives/blocking_action_mixin.dart';
import 'inspector_controller.dart';
import 'inspector_screen.dart';
import 'layout_explorer/layout_explorer.dart';

class InspectorDetails extends StatelessWidget {
  const InspectorDetails({
    required this.controller,
    super.key,
  });

  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      clip: true,
      child: Column(
        children: [
          Expanded(
            child: LayoutExplorerTab(
              controller: controller,
            ),
          ),
        ],
      ),
    );
  }
}

class InspectorExpandCollapseButtons extends StatefulWidget {
  const InspectorExpandCollapseButtons({
    super.key,
    required this.controller,
  });

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
      }),
    );
  }

  void _onCollapseClick() {
    ga.select(
      gac.inspector,
      gac.collapseAll,
    );
  }
}
