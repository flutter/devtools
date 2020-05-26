// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/table.dart';
import '../../flutter/theme.dart';
import '../../http/http.dart';
import '../../http/http_request_data.dart';
import '../../utils.dart';

// Approximately double the indent of the expandable tile's title.
const double _rowIndentPadding = 30;

// No padding between the last element and the divider of a expandable tile.
const double _rowSpacingPadding = 15;

const EdgeInsets _rowPadding =
    EdgeInsets.only(left: _rowIndentPadding, bottom: _rowSpacingPadding);

/// Helper to build ExpansionTile widgets for inspector views.
ExpansionTile _buildTile(
  String title,
  List<Widget> children, {
  Key key,
}) {
  return ExpansionTile(
    key: key,
    title: Text(
      title,
    ),
    children: children,
    initiallyExpanded: true,
  );
}

/// This widget displays general HTTP request / response information that is
/// contained in the headers, in addition to the standard connection information.
class HttpRequestHeadersView extends StatelessWidget {
  const HttpRequestHeadersView(this.data);

  @visibleForTesting
  static const generalKey = Key('General');
  @visibleForTesting
  static const requestHeadersKey = Key('Request Headers');
  @visibleForTesting
  static const responseHeadersKey = Key('Response Headers');

  final HttpRequestData data;

  Widget _buildRow(
    BuildContext context,
    String key,
    dynamic value,
    BoxConstraints constraints,
  ) {
    return Container(
      width: constraints.minWidth,
      padding: _rowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$key: ',
            style: Theme.of(context).textTheme.subtitle2,
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 5,
            ),
          ),
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
              'General',
              [
                for (final entry in data.general.entries)
                  _buildRow(
                    context,
                    // TODO(kenz): ensure the default case of `entry.key` looks
                    // fine.
                    entry.key,
                    entry.value.toString(),
                    constraints,
                  ),
              ],
              key: generalKey,
            ),
            _buildTile(
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
              key: responseHeadersKey,
            ),
            _buildTile(
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
              key: requestHeadersKey,
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

  @visibleForTesting
  static const requestCookiesKey = Key('Request Cookies');
  @visibleForTesting
  static const responseCookiesKey = Key('Response Cookies');

  final HttpRequestData data;

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
        ],
      ],
    );
  }

  DataCell _buildCell(String value) => DataCell(Text(value ?? '--'));

  DataCell _buildIconCell(IconData icon) =>
      DataCell(Icon(icon, size: defaultIconSize));

  Widget _buildCookiesTable(
    BuildContext context,
    String title,
    List<Cookie> cookies,
    BoxConstraints constraints,
    Key key, {
    bool requestCookies = false,
  }) {
    final theme = Theme.of(context);
    DataColumn _buildColumn(
      String title, {
      bool numeric = false,
    }) {
      return DataColumn(
        label: Expanded(
          child: Text(
            title ?? '--',
            style: theme.textTheme.subtitle1,
            overflow: TextOverflow.fade,
          ),
        ),
        numeric: numeric,
      );
    }

    return _buildTile(
      title,
      [
        // Add a divider between the tile's title and the cookie table headers for
        // symmetry.
        const Divider(
          // Remove extra padding at the top of the divider; the tile's title
          // already has bottom padding.
          height: 0,
        ),
        Align(
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
                key: key,
                dataRowHeight: defaultRowHeight,
                // NOTE: if this list of columns change, _buildRow will need
                // to be updated to match.
                columns: [
                  _buildColumn('Name'),
                  _buildColumn('Value'),
                  if (!requestCookies) ...[
                    _buildColumn('Domain'),
                    _buildColumn('Path'),
                    _buildColumn('Expires / Max Age'),
                    _buildColumn('Size', numeric: true),
                    _buildColumn('HttpOnly'),
                    _buildColumn('Secure'),
                  ]
                ],
                rows: [
                  for (int i = 0; i < cookies.length; ++i)
                    _buildRow(
                      i,
                      cookies[i],
                      requestCookies: requestCookies,
                    ),
                ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            if (responseCookies.isNotEmpty)
              _buildCookiesTable(
                context,
                'Response Cookies',
                responseCookies,
                constraints,
                responseCookiesKey,
              ),
            // Add padding between the cookie tables if displaying both
            // response and request cookies.
            if (responseCookies.isNotEmpty && requestCookies.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
              ),
            if (requestCookies.isNotEmpty)
              _buildCookiesTable(
                context,
                'Request Cookies',
                requestCookies,
                constraints,
                requestCookiesKey,
                requestCookies: true,
              ),
          ],
        );
      },
    );
  }
}

/// A [Widget] which displays timing information for an HTTP request.
class HttpRequestTimingView extends StatelessWidget {
  const HttpRequestTimingView(this.data);

  final HttpRequestData data;

  Widget _buildRow(
    BuildContext context,
    String key,
    dynamic value,
  ) {
    return Container(
      padding: _rowPadding,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$key: ',
                style: Theme.of(context).textTheme.subtitle2,
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

    return ListView(
      children: events,
    );
  }
}
