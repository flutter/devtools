// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../common_widgets.dart';
import '../http/http_request_data.dart';
import '../theme.dart';
import '../ui/tab.dart';
import 'network_model.dart';
import 'network_request_inspector_views.dart';

/// A [Widget] which displays information about a network request.
class NetworkRequestInspector extends StatefulWidget {
  const NetworkRequestInspector(this.data);

  static const _overviewTabTitle = 'Overview';
  static const _headersTabTitle = 'Headers';
  static const _requestTabTitle = 'Request';
  static const _responseTabTitle = 'Response';
  static const _cookiesTabTitle = 'Cookies';

  @visibleForTesting
  static const overviewTabKey = Key(_overviewTabTitle);
  @visibleForTesting
  static const headersTabKey = Key(_headersTabTitle);
  @visibleForTesting
  static const requestTabKey = Key(_requestTabTitle);
  @visibleForTesting
  static const responseTabKey = Key(_responseTabTitle);
  @visibleForTesting
  static const cookiesTabKey = Key(_cookiesTabTitle);
  @visibleForTesting
  static const noRequestSelectedKey = Key('No Request Selected');

  final NetworkRequest data;

  @override
  State<NetworkRequestInspector> createState() =>
      _NetworkRequestInspectorState();
}

class _NetworkRequestInspectorState extends State<NetworkRequestInspector>
    with TickerProviderStateMixin {
  TabController _tabController;

  List<DevToolsTab> _tabs;

  int _currentTabControllerIndex = 0;

  void _initTabController() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _tabs = <DevToolsTab>[
      _buildTab(NetworkRequestInspector._overviewTabTitle),
      if (widget.data is HttpRequestData) ...[
        _buildTab(NetworkRequestInspector._headersTabTitle),
        if ((widget.data as HttpRequestData).requestBody != null)
          _buildTab(NetworkRequestInspector._requestTabTitle),
        if ((widget.data as HttpRequestData).responseBody != null)
          _buildTab(NetworkRequestInspector._responseTabTitle),
        if ((widget.data as HttpRequestData).hasCookies)
          _buildTab(NetworkRequestInspector._cookiesTabTitle),
      ],
    ];
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
    );
    if (_currentTabControllerIndex >= _tabController.length) {
      _currentTabControllerIndex = 0;
    }
    _tabController
      ..index = _currentTabControllerIndex
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_currentTabControllerIndex != _tabController.index) {
      _currentTabControllerIndex = _tabController.index;
      ga.select(
        analytics_constants.network,
        _tabs[_currentTabControllerIndex].gaId,
      );
    }
  }

  Widget _buildTab(String tabName) {
    return DevToolsTab(
      key: ValueKey<String>(tabName),
      gaId: tabName,
      child: Text(
        tabName,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initTabController();
  }

  @override
  void didUpdateWidget(NetworkRequestInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _initTabController();
      final currentTabIndex = _tabController.index;
      // We are now showing this tab for a new network request, so record a
      // selection of this tab for analytics.
      ga.select(
        analytics_constants.network,
        _tabs[currentTabIndex].gaId,
      );
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabbedContent = Column(
      children: [
        Row(
          children: [
            Flexible(
              child: TabBar(
                labelColor: Theme.of(context).textTheme.bodyText1.color,
                controller: _tabController,
                tabs: _tabs,
              ),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            physics: defaultTabBarViewPhysics,
            controller: _tabController,
            children: [
              NetworkRequestOverviewView(widget.data),
              if (widget.data is HttpRequestData) ...[
                HttpRequestHeadersView(widget.data),
                if ((widget.data as HttpRequestData).requestBody != null)
                  HttpRequestView(widget.data),
                if ((widget.data as HttpRequestData).responseBody != null)
                  HttpResponseView(widget.data),
                if ((widget.data as HttpRequestData).hasCookies)
                  HttpRequestCookiesView(widget.data),
              ],
            ],
          ),
        ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).canvasColor,
      child: RoundedOutlinedBorder(
        child: (widget.data == null)
            ? Center(
                child: Text(
                  'No request selected',
                  key: NetworkRequestInspector.noRequestSelectedKey,
                  style: Theme.of(context).textTheme.headline6,
                ),
              )
            : tabbedContent,
      ),
    );
  }
}
