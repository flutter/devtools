// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../http_request_data.dart';
import 'http_cookies_tab.dart';
import 'http_headers_tab.dart';
import 'http_timing_tab.dart';

/// A [Widget] which displays information about an HTTP request.
class HttpRequestInspector extends StatelessWidget {
  const HttpRequestInspector(this.data);

  @override
  Widget build(BuildContext context) {
    final hasCookies = data?.hasCookies ?? false;
    final tabs = <Tab>[
      _buildTab('Headers'),
      _buildTab('Timing'),
      if (hasCookies) _buildTab('Cookies'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).focusColor,
        ),
      ),
      child: (data == null)
          ? const Center(
              child: Text(
                'No request selected',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            )
          : DefaultTabController(
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
                        HttpRequestHeadersTab(data),
                        HttpRequestTimingTab(data),
                        if (hasCookies) HttpRequestCookiesTab(data),
                      ],
                    ),
                  ),
                ],
              ),
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

  final HttpRequestData data;
}
