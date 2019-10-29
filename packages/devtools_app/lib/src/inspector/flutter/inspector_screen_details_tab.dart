// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../inspector/inspector_text_styles.dart' as inspector_text_styles;
import '../diagnostics_node.dart';
import 'inspector_data_models.dart';
import 'inspector_tree_flutter.dart';

class InspectorDetailsTabController extends StatelessWidget {
  const InspectorDetailsTabController({
    this.detailsTree,
    this.expandCollapseButtons,
    this.expandCollapseSupported,
    this.summaryTreeController,
    Key key,
  }) : super(key: key);

  final bool expandCollapseSupported;
  final Widget detailsTree;
  final Widget expandCollapseButtons;
  final InspectorTreeControllerFlutter summaryTreeController;

  @override
  Widget build(BuildContext context) {
    final enableExperimentalStoryOfLayout =
        InspectorTreeControllerFlutter.enableExperimentalStoryOfLayout;
    final tabs = <Tab>[
      const Tab(text: 'Details Tree'),
      if (enableExperimentalStoryOfLayout) const Tab(text: 'Layout Details')
    ];
    final tabViews = <Widget>[
      detailsTree,
      if (enableExperimentalStoryOfLayout)
        LayoutDetailsTab(controller: summaryTreeController),
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
                  Container(
                    color: Theme.of(context).focusColor,
                    child: TabBar(
                      tabs: tabs,
                      isScrollable: true,
                    ),
                  ),
                  if (expandCollapseSupported)
                    Expanded(
                      child: expandCollapseButtons,
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

  final InspectorTreeControllerFlutter controller;

  @override
  _LayoutDetailsTabState createState() => _LayoutDetailsTabState();
}

class _LayoutDetailsTabState extends State<LayoutDetailsTab>
    with AutomaticKeepAliveClientMixin<LayoutDetailsTab>
    implements InspectorControllerClient {
  InspectorTreeControllerFlutter get controller => widget.controller;

  RemoteDiagnosticsNode get selected => controller.selection?.diagnostic;

  // Lifecycle hooks
  @override
  void initState() {
    super.initState();
    controller.addClient(this);
  }

  @override
  void dispose() {
    super.dispose();
    controller.removeClient(this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (selected == null)
      return const Center(
        child: CircularProgressIndicator(),
      );
    if (!selected.isFlex)
      return Container(
        // TODO(albertusangga): Visualize non flex widget constraint with Bounding Box model
        child: const Text('TODOs for Non Flex widget'),
      );
    return StoryOfYourFlexWidget(
      diagnostic: selected,
      // TODO(albertusangga): Optimize and cache deserialization instead of always calling it when state changes
      properties: RenderFlexProperties.fromJson(selected.renderObject),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void onChanged() {
    setState(() {});
  }

  @override
  void scrollToRect(Rect rect) {
    // do nothing since we are not doing scrolling here
  }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Widget> children = [
      for (var child in diagnostic.childrenNow)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.backgroundColor,
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
    final Widget flexWidget = properties.type == Row
        ? Row(children: children)
        : Column(children: children);
    final String flexWidgetName = properties.type.toString();
    return Dialog(
      child: Container(
        margin: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                'Story of the flex layout of your $flexWidgetName widget',
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
                        flexWidgetName,
                        style: inspector_text_styles.regularBold,
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16.0),
                          child: flexWidget,
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
