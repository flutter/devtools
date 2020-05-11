// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/theme.dart';
import '../inspector_controller.dart';
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
  static const _detailsTreeTabIndex = 0;
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
      _buildTab('Details Tree'),
      if (widget.layoutExplorerSupported) _buildTab('Layout Explorer'),
    ];
    final tabViews = <Widget>[
      widget.detailsTree,
      if (widget.layoutExplorerSupported)
        LayoutExplorerTab(controller: widget.controller),
    ];
    final _tabController = widget.layoutExplorerSupported
        ? _tabControllerWithLayoutExplorer
        : _tabControllerWithoutLayoutExplorer;
    final focusColor = Theme.of(context).focusColor;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: focusColor),
      ),
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
                      controller: _tabController,
                      labelColor: Theme.of(context).textTheme.bodyText1.color,
                      tabs: tabs,
                      isScrollable: true,
                    ),
                  ),
                ),
                if (widget.actionButtons != null &&
                    _tabController.index == _detailsTreeTabIndex)
                  Expanded(
                    child: widget.actionButtons,
                  ),
              ],
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: defaultTabBarViewPhysics,
              controller: _tabController,
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String tabName) {
    return Tab(
      child: Text(
        tabName,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
