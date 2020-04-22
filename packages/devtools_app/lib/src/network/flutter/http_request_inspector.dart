// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../http/http_request_data.dart';
import 'http_request_inspector_views.dart';

/// A [Widget] which displays information about an HTTP request.
class HttpRequestInspector extends StatelessWidget {
  const HttpRequestInspector(this.data);

  static const _headersTabTitle = 'Headers';
  static const _cookiesTabTitle = 'Cookies';
  static const _timingTabTitle = 'Timing';

  @visibleForTesting
  static const cookiesTabKey = Key(_cookiesTabTitle);
  @visibleForTesting
  static const headersTabKey = Key(_headersTabTitle);
  @visibleForTesting
  static const timingTabKey = Key(_timingTabTitle);
  @visibleForTesting
  static const noRequestSelectedKey = Key('No Request Selected');

  final HttpRequestData data;

  Widget _buildTab(String tabName) {
    return Tab(
      key: ValueKey<String>(tabName),
      child: Text(
        tabName,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCookies = data?.hasCookies ?? false;
    final tabs = <Tab>[
      _buildTab(_headersTabTitle),
      _buildTab(_timingTabTitle),
      if (hasCookies) _buildTab(_cookiesTabTitle),
    ];
    final tabbedContent = DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: TabBar(
                  tabs: tabs,
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                HttpRequestHeadersView(data),
                HttpRequestTimingView(data),
                if (hasCookies) HttpRequestCookiesView(data),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).canvasColor,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).focusColor,
          ),
        ),
        child: (data == null)
            ? Center(
                child: Text(
                  'No request selected',
                  key: noRequestSelectedKey,
                  style: Theme.of(context).textTheme.headline6,
                ),
              )
            : tabbedContent,
      ),
    );
  }
}
