// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:flutter/material.dart';

import '../primitives/auto_dispose_mixin.dart';
import '../shared/theme.dart';
import '../shared/utils.dart';
import '../ui/tab.dart';
import 'inspector_controller.dart';
import 'layout_explorer/layout_explorer.dart';

class InspectorDetailsTabController extends StatefulWidget {
  const InspectorDetailsTabController({
    this.detailsTree,
    this.actionButtons,
    this.controller,
    Key key,
  }) : super(key: key);

  final Widget detailsTree;
  final Widget actionButtons;
  final InspectorController controller;

  @override
  _InspectorDetailsTabControllerState createState() =>
      _InspectorDetailsTabControllerState();
}

class _InspectorDetailsTabControllerState
    extends State<InspectorDetailsTabController>
    with TickerProviderStateMixin, AutoDisposeMixin {
  static const _detailsTreeTabIndex = 1;
  static const _tabsLengthWithLayoutExplorer = 2;

  TabController _tabController;

  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(
      _tabController = TabController(
        length: _tabsLengthWithLayoutExplorer,
        vsync: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      _buildTab('Layout Explorer'),
      _buildTab('Widget Details Tree'),
    ];
    final tabViews = <Widget>[
      LayoutExplorerTab(controller: widget.controller),
      widget.detailsTree,
    ];
    final theme = Theme.of(context);
    final focusColor = theme.focusColor;
    final borderSide = BorderSide(color: focusColor);
    final hasActionButtons = widget.actionButtons != null &&
        _tabController.index == _detailsTreeTabIndex;

    return Column(
      children: <Widget>[
        Container(
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
