// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/http/http_request_data.dart';
import '../../shared/ui/tab.dart';
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

  // TODO(kenz): remove these keys and use a text finder to lookup widgets in test.

  @visibleForTesting
  static const overviewTabKey = Key(_overviewTabTitle);
  @visibleForTesting
  static const headersTabKey = Key(_headersTabTitle);
  @visibleForTesting
  static const responseTabKey = Key(_responseTabTitle);
  @visibleForTesting
  static const cookiesTabKey = Key(_cookiesTabTitle);
  @visibleForTesting
  static const noRequestSelectedKey = Key('No Request Selected');

  final NetworkController controller;

  DevToolsTab _buildTab({required String tabName, Widget? trailing}) {
    return DevToolsTab.create(
      tabName: tabName,
      gaPrefix: 'requestInspectorTab',
      trailing: trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NetworkRequest?>(
      valueListenable: controller.selectedRequest,
      builder: (context, data, _) {
        late final tabs = <DevToolsTab>[
          _buildTab(tabName: NetworkRequestInspector._overviewTabTitle),
          if (data is DartIOHttpRequestData) ...[
            _buildTab(tabName: NetworkRequestInspector._headersTabTitle),
            if (data.requestBody != null)
              _buildTab(
                tabName: NetworkRequestInspector._requestTabTitle,
                trailing: HttpViewTrailingCopyButton(
                  data,
                  (data) => data.requestBody,
                ),
              ),
            if (data.responseBody != null)
              _buildTab(
                tabName: NetworkRequestInspector._responseTabTitle,
                trailing: HttpViewTrailingCopyButton(
                  data,
                  (data) => data.responseBody,
                ),
              ),
            if (data.hasCookies)
              _buildTab(tabName: NetworkRequestInspector._cookiesTabTitle),
          ],
        ];
        late final tabViews = [
          if (data != null) ...[
            NetworkRequestOverviewView(data),
            if (data is DartIOHttpRequestData) ...[
              HttpRequestHeadersView(data),
              if (data.requestBody != null) HttpRequestView(data),
              if (data.responseBody != null) HttpResponseView(data),
              if (data.hasCookies) HttpRequestCookiesView(data),
            ],
          ]
        ].map((e) => OutlineDecoration.onlyTop(child: e)).toList();

        return RoundedOutlinedBorder(
          child: (data == null)
              ? Center(
                  child: Text(
                    'No request selected',
                    key: NetworkRequestInspector.noRequestSelectedKey,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                )
              : AnalyticsTabbedView(
                  tabs: tabs,
                  tabViews: tabViews,
                  gaScreen: gac.network,
                ),
        );
      },
    );
  }
}
