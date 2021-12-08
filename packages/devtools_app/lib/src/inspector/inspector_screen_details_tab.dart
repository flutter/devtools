// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../auto_dispose_mixin.dart';
import '../theme.dart';
import '../ui/tab.dart';
import '../utils.dart';
import 'inspector_controller.dart';
import 'layout_explorer/layout_explorer.dart';

class InspectorDetailsTabController extends StatefulWidget {
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

  @override
  _InspectorDetailsTabControllerState createState() =>
      _InspectorDetailsTabControllerState();
}

class _InspectorDetailsTabControllerState
    extends State<InspectorDetailsTabController>
    with TickerProviderStateMixin, AutoDisposeMixin {
  static const _detailsTreeTabIndex = 1;
  static const _tabsLengthWithLayoutExplorer = 2;
  static const _tabsLengthWithoutLayoutExplorer = 1;

  TabController _tabControllerWithLayoutExplorer;
  TabController _tabControllerWithoutLayoutExplorer;

  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(
      _tabControllerWithLayoutExplorer =
          TabController(length: _tabsLengthWithLayoutExplorer, vsync: this),
    );
    addAutoDisposeListener(
      _tabControllerWithoutLayoutExplorer =
          TabController(length: _tabsLengthWithoutLayoutExplorer, vsync: this),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      if (widget.layoutExplorerSupported) _buildTab('Layout Explorer'),
      _buildTab('Widget Details Tree'),
    ];
    final tabViews = <Widget>[
      if (widget.layoutExplorerSupported)
        LayoutExplorerTab(controller: widget.controller),
      widget.detailsTree,
    ];
    final _tabController = widget.layoutExplorerSupported
        ? _tabControllerWithLayoutExplorer
        : _tabControllerWithoutLayoutExplorer;

    final theme = Theme.of(context);
    final focusColor = theme.focusColor;
    final borderSide = BorderSide(color: focusColor);
    final hasActionButtons = widget.actionButtons != null &&
        _tabController.index == _detailsTreeTabIndex;

    return Column(
      children: <Widget>[
        Container(
          // Add [denseSpacing] to add slight padding around the expand /
          // collapse buttons.
          height: defaultButtonHeight +
              (isDense() ? denseModeDenseSpacing : denseSpacing),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).focusColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              TabBar(
                controller: _tabController,
                labelColor: theme.textTheme.bodyText1.color,
                tabs: tabs,
                isScrollable: true,
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.centerRight,
                  child: hasActionButtons
                      ? widget.actionButtons
                      : const SizedBox(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: borderSide,
                bottom: borderSide,
                right: borderSide,
              ),
            ),
            child: TabBarView(
              physics: defaultTabBarViewPhysics,
              controller: _tabController,
              children: tabViews,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String tabName) {
    return DevToolsTab(
      child: Text(
        tabName,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
