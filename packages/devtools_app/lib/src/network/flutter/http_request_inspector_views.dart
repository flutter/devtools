// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:recase/recase.dart';

import '../../utils.dart';
import '../http.dart';
import '../http_request_data.dart';

/// This widget displays general HTTP request / response information that is
/// contained in the headers, in addition to the standard connection information.
class HttpRequestHeadersView extends StatelessWidget {
  const HttpRequestHeadersView(this.data);

  final HttpRequestData data;

  ExpansionTile _buildTile(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return ExpansionTile(
      title: Text(
        title,
      ),
      children: children,
      initiallyExpanded: true,
    );
  }

  Widget _buildRow(
      BuildContext context, String key, dynamic value, constraints) {
    return Container(
      width: constraints.minWidth,
      padding: const EdgeInsets.only(
        left: 30,
        bottom: 15,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$key: ',
            style: Theme.of(context).textTheme.subtitle,
          ),
          Expanded(
              child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            maxLines: 5,
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          children: [
            _buildTile(
              context,
              'General',
              [
                for (final entry in data.general.entries)
                  _buildRow(
                    context,
                    ReCase(entry.key).titleCase,
                    entry.value.toString(),
                    constraints,
                  ),
              ],
            ),
            _buildTile(
              context,
              'Response Headers',
              [
                if (data.responseHeaders != null)
                  for (final entry in data.responseHeaders.entries)
                    _buildRow(
                      context,
                      entry.key,
                      entry.value.toString(),
                      constraints,
                    ),
              ],
            ),
            _buildTile(
              context,
              'Request Headers',
              [
                if (data.requestHeaders != null)
                  for (final entry in data.requestHeaders.entries)
                    _buildRow(
                      context,
                      entry.key,
                      entry.value.toString(),
                      constraints,
                    ),
              ],
            )
          ],
        );
      },
    );
  }
}

/// A [Widget] which displays [Cookie] information in a tab.
class HttpRequestCookiesView extends StatelessWidget {
  const HttpRequestCookiesView(this.data);

  final HttpRequestData data;

  DataColumn _buildColumn(
    BuildContext context,
    String title, {
    bool numeric = false,
  }) {
    return DataColumn(
      label: Expanded(
        child: Text(
          title ?? '--',
          style: Theme.of(context).textTheme.subhead,
          overflow: TextOverflow.fade,
        ),
      ),
      numeric: numeric,
    );
  }

  DataRow _buildRow(int index, Cookie cookie, {bool requestCookies = false}) {
    return DataRow.byIndex(
      index: index,
      // NOTE: if this list of cells change, the columns of the DataTable
      // below will need to be updated.
      cells: [
        _buildCell(cookie.name),
        _buildCell(cookie.value),
        if (!requestCookies) ...[
          _buildCell(cookie.domain),
          _buildCell(cookie.path),
          _buildCell(cookie.expires?.toString()),
          _buildCell(cookie.value.length.toString()),
          _buildIconCell(!cookie.httpOnly ? Icons.check : Icons.close),
          _buildIconCell(!cookie.secure ? Icons.check : Icons.close),
        ]
      ],
    );
  }

  DataCell _buildCell(String value) => DataCell(Text(value ?? '--'));
  DataCell _buildIconCell(IconData icon) => DataCell(Icon(icon));

  Widget _buildCookiesTable(
    BuildContext context,
    String title,
    List<Cookie> cookies,
    BoxConstraints constraints, {
    bool requestCookies = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: theme.textTheme.subhead.apply(
              color: theme.accentColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            bottom: 24.0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: requestCookies
                    ? const BoxConstraints()
                    : BoxConstraints(
                        minWidth: constraints.minWidth,
                      ),
                child: DataTable(
                  // NOTE: if this list of columns change, _buildRow will need
                  // to be updated to match.
                  columns: [
                    _buildColumn(context, 'Name'),
                    _buildColumn(context, 'Value'),
                    if (!requestCookies) ...[
                      _buildColumn(context, 'Domain'),
                      _buildColumn(context, 'Path'),
                      _buildColumn(context, 'Expires / Max Age'),
                      _buildColumn(context, 'Size', numeric: true),
                      _buildColumn(context, 'HttpOnly'),
                      _buildColumn(context, 'Secure'),
                    ]
                  ],
                  rows: [
                    for (int i = 0; i < cookies.length; ++i)
                      _buildRow(
                        i,
                        cookies[i],
                        requestCookies: requestCookies,
                      )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestCookies = data.requestCookies;
    final responseCookies = data.responseCookies;
    return Container(
      padding: const EdgeInsets.only(
        left: 14.0,
        top: 18.0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              if (responseCookies.isNotEmpty)
                _buildCookiesTable(
                  context,
                  'Response Cookies',
                  responseCookies,
                  constraints,
                ),
              if (requestCookies.isNotEmpty)
                _buildCookiesTable(
                  context,
                  'Request Cookies',
                  requestCookies,
                  constraints,
                  requestCookies: true,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A [Widget] which displays timing information for an HTTP request.
class HttpRequestTimingView extends StatelessWidget {
  const HttpRequestTimingView(this.data);

  final HttpRequestData data;

  ExpansionTile _buildTile(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return ExpansionTile(
      title: Text(
        title,
      ),
      children: children,
      initiallyExpanded: true,
    );
  }

  Widget _buildRow(
    BuildContext context,
    String key,
    dynamic value,
  ) {
    return Container(
      padding: const EdgeInsets.only(
        left: 30,
        bottom: 15,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$key: ',
                style: Theme.of(context).textTheme.subtitle,
              ),
              Text(value),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = <Widget>[];
    for (final instant in data.instantEvents) {
      final duration = instant.timeRange.duration;
      events.add(
        _buildTile(
          context,
          instant.name,
          [
            _buildRow(
              context,
              'Duration',
              '${msText(duration)}',
            ),
          ],
        ),
      );
    }
    events.add(
      _buildTile(
        context,
        'Total',
        [
          _buildRow(
            context,
            'Duration',
            '${msText(data.duration)}',
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(
        left: 14.0,
        top: 18.0,
      ),
      child: ListView(
        children: events,
      ),
    );
  }
}
