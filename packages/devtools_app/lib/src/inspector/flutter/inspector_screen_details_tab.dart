// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../inspector/inspector_text_styles.dart' as inspector_text_styles;
import '../diagnostics_node.dart';
import '../inspector_controller.dart';
import 'inspector_data_models.dart';

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

  Widget buildTab(String tabName) {
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
      buildTab('Details Tree'),
      if (enableExperimentalStoryOfLayout) buildTab('Layout Details'),
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
    if (!selected.isFlex)
      // TODO(albertusangga): Visualize non-flex widget constraint model
      return Container(
        child: const Text(
          'TODOs for Non Flex widget',
        ),
      );
    return StoryOfYourFlexWidget(
      diagnostic: selected,
      // TODO(albertusangga): Cache this instead of recomputing every build
      properties: RenderFlexProperties.fromJson(selected.renderObject),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

@immutable
class StoryOfYourFlexWidget extends StatelessWidget {
  const StoryOfYourFlexWidget({
    this.diagnostic,
    this.properties,
    Key key,
  }) : super(key: key);

  final RemoteDiagnosticsNode diagnostic;
  final RenderFlexProperties properties;

  List<Widget> visualizeChildren(BuildContext context) {
    if (!diagnostic.hasChildren) return [const SizedBox()];
    final theme = Theme.of(context);
    return [
      for (var child in diagnostic.childrenNow)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.primaryColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor,
                  offset: Offset.zero,
                  blurRadius: 10.0,
                )
              ],
            ),
            child: Center(
              child: Text(child.description),
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final children = visualizeChildren(context);
    final flexVisualizerWidget = Flex(
      direction: properties.direction,
      children: children,
    );
    final flexType = properties.type.toString();
    return Dialog(
      child: Container(
        margin: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                // TODO(albertusangga): Reuse existing material design header text style
                'Story of the flex layout of your $flexType widget',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0,
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).primaryColor,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        flexType,
                        style: inspector_text_styles.regularBold,
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16.0),
                          child: flexVisualizerWidget,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
