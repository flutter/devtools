// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../diagnostics_node.dart';
import '../inspector_controller.dart';
import 'story_of_your_layout/flex.dart';

class InspectorDetailsTabController extends StatelessWidget {
  const InspectorDetailsTabController({
    this.detailsTree,
    this.actionButtons,
    this.controller,
    this.layoutExplorerSupported,
    Key key,
  }) : super(key: key);

  final Widget detailsTree;
  final Widget actionButtons;
  final InspectorController controller;
  final bool layoutExplorerSupported;

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
    final tabs = <Tab>[
      _buildTab('Details Tree'),
      if (layoutExplorerSupported) _buildTab('Layout Explorer'),
    ];
    final tabViews = <Widget>[
      detailsTree,
      if (layoutExplorerSupported) LayoutExplorerTab(controller: controller),
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
                      color: focusColor,
                      child: TabBar(
                        labelColor: Theme.of(context).textTheme.body1.color,
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

/// Tab that acts as a proxy to decide which widget to be displayed
class LayoutExplorerTab extends StatefulWidget {
  const LayoutExplorerTab({Key key, this.controller}) : super(key: key);

  final InspectorController controller;

  @override
  _LayoutExplorerTabState createState() => _LayoutExplorerTabState();
}

class _LayoutExplorerTabState extends State<LayoutExplorerTab>
    with AutomaticKeepAliveClientMixin<LayoutExplorerTab> {
  InspectorController get controller => widget.controller;

  RemoteDiagnosticsNode get selected => controller?.selectedNode?.diagnostic;

  RemoteDiagnosticsNode previousSelection;

  Widget rootWidget(RemoteDiagnosticsNode node) {
    if (StoryOfYourFlexWidget.shouldDisplay(node))
      return StoryOfYourFlexWidget(controller);
    return const Center(
      child: Text(
        'Currently, Layout Explorer only supports Flex-based widgets'
        ' (e.g., Row, Column, Flex) or their direct children.',
        textAlign: TextAlign.center,
        overflow: TextOverflow.clip,
      ),
    );
  }

  void onSelectionChanged() {
    if (rootWidget(previousSelection).runtimeType !=
        rootWidget(selected).runtimeType) {
      setState(() => previousSelection = selected);
    }
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
    return rootWidget(selected);
  }

  @override
  bool get wantKeepAlive => true;
}
