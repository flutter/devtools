// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../analytics/constants.dart' as analytics_constants;
import '../../http/http_request_data.dart';
import '../../shared/common_widgets.dart';
import '../../ui/tab.dart';
import 'network_controller.dart';
import 'network_model.dart';
import 'network_request_inspector_views.dart';

/// A [Widget] which displays information about a network request.
class NetworkRequestInspector extends StatelessWidget {
  const NetworkRequestInspector(this.controller);

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

  final NetworkController controller;

  DevToolsTab _buildTab(String tabName) {
    return DevToolsTab.create(
      tabName: tabName,
      gaPrefix: 'requestInspectorTab',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NetworkRequest?>(
      valueListenable: controller.selectedRequest,
      builder: (context, data, _) {
        final tabs = <DevToolsTab>[
          _buildTab(NetworkRequestInspector._overviewTabTitle),
          if (data is DartIOHttpRequestData) ...[
            _buildTab(NetworkRequestInspector._headersTabTitle),
            if (data.requestBody != null)
              _buildTab(NetworkRequestInspector._requestTabTitle),
            if (data.responseBody != null)
              _buildTab(NetworkRequestInspector._responseTabTitle),
            if (data.hasCookies)
              _buildTab(NetworkRequestInspector._cookiesTabTitle),
          ],
        ];
        return Card(
          margin: EdgeInsets.zero,
          color: Theme.of(context).canvasColor,
          child: RoundedOutlinedBorder(
            child: (data == null)
                ? Center(
                    child: Text(
                      'No request selected',
                      key: NetworkRequestInspector.noRequestSelectedKey,
                      style: Theme.of(context).textTheme.headline6,
                    ),
                  )
                : AnalyticsTabbedView(
                    tabs: tabs,
                    tabViews: [
                      NetworkRequestOverviewView(data),
                      if (data is DartIOHttpRequestData) ...[
                        HttpRequestHeadersView(data),
                        if (data.requestBody != null) HttpRequestView(data),
                        if (data.responseBody != null) HttpResponseView(data),
                        if (data.hasCookies) HttpRequestCookiesView(data),
                      ],
                    ],
                    gaScreen: analytics_constants.network,
                    // TODO(kenz): Consider using the outlined style
                    outlined: false,
                  ),
          ),
        );
      },
    );
  }
}
