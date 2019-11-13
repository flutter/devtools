// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../diagnostics_node.dart';
import '../inspector_controller.dart';
import 'inspector_data_models.dart';
import 'story_of_your_layout/flex.dart';

class InspectorDetailsTabController extends StatelessWidget {
  const InspectorDetailsTabController({
    this.detailsTree,
    this.actionButtons,
    this.controller,
    Key key,
  }) : super(key: key);

  final Widget detailsTree;
  final Widget actionButtons;
  final InspectorController controller;

  Widget _buildTab(String tabName) {
    return Tab(
      child: Text(
        tabName,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enableExperimentalStoryOfLayout =
        InspectorController.enableExperimentalStoryOfLayout;
    final tabs = <Tab>[
      _buildTab('Details Tree'),
      if (enableExperimentalStoryOfLayout) _buildTab('Layout Details'),
    ];
    final tabViews = <Widget>[
      detailsTree,
      if (enableExperimentalStoryOfLayout)
        LayoutDetailsTab(controller: controller),
    ];
    final focusColor = Theme.of(context).focusColor;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: focusColor),
      ),
      child: DefaultTabController(
        length: tabs.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Container(
                      color: Theme.of(context).focusColor,
                      child: TabBar(
                        tabs: tabs,
                        isScrollable: true,
                      ),
                    ),
                  ),
                  if (actionButtons != null)
                    Expanded(
                      child: actionButtons,
                    ),
                ],
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: tabViews,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LayoutDetailsTab extends StatefulWidget {
  const LayoutDetailsTab({Key key, this.controller}) : super(key: key);

  final InspectorController controller;

  @override
  _LayoutDetailsTabState createState() => _LayoutDetailsTabState();
}

class _LayoutDetailsTabState extends State<LayoutDetailsTab>
    with AutomaticKeepAliveClientMixin<LayoutDetailsTab> {
  InspectorController get controller => widget.controller;

  RemoteDiagnosticsNode get selected => controller?.selectedNode?.diagnostic;

  void onSelectionChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    controller.addSelectionListener(onSelectionChanged);
  }

  @override
  void dispose() {
    controller.removeSelectionListener(onSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (selected == null) return const SizedBox();
    final properties = LayoutProperties(selected);
    if (!properties.isFlex)
      // TODO(albertusangga): Visualize non-flex widget constraint model
      return Container(
        child: const Text(
          'TODOs for Non Flex widget',
        ),
      );
    return StoryOfYourFlexWidget(
      // TODO(albertusangga): Cache this instead of recomputing every build,
      FlexLayoutProperties.fromRemoteDiagnosticsNode(selected),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
