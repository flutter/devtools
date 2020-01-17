// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../http_request_data.dart';
import 'http_request_inspector_views.dart';

/// A [Widget] which displays information about an HTTP request.
class HttpRequestInspector extends StatelessWidget {
  const HttpRequestInspector(this.data);

  final HttpRequestData data;

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
    final hasCookies = data?.hasCookies ?? false;
    final tabs = <Tab>[
      _buildTab('Headers'),
      _buildTab('Timing'),
      if (hasCookies) _buildTab('Cookies'),
    ];
    final tabbedContent = DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  child: TabBar(
                    tabs: tabs,
                  ),
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
                  style: Theme.of(context).textTheme.title,
                ),
              )
            : tabbedContent,
      ),
    );
  }
}
