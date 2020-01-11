// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:recase/recase.dart';

import '../../utils.dart';
import '../http.dart';
import '../http_request_data.dart';

// Approximately double the indent of the expandable tile's title.
const double _rowIndentPadding = 30;

// No padding between the last element and the divider of a expandable tile.
const double _rowSpacingPadding = 15;

const EdgeInsets _rowPadding =
    EdgeInsets.only(left: _rowIndentPadding, bottom: _rowSpacingPadding);

/// Helper to build ExpansionTile widgets for inspector views.
ExpansionTile _buildTile(
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

/// This widget displays general HTTP request / response information that is
/// contained in the headers, in addition to the standard connection information.
class HttpRequestHeadersView extends StatelessWidget {
  const HttpRequestHeadersView(this.data);

  final HttpRequestData data;

  Widget _buildRow(
      BuildContext context, String key, dynamic value, constraints) {
    return Container(
      width: constraints.minWidth,
      padding: _rowPadding,
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
                    ReCase(entry.key).titleCase,
                    entry.value.toString(),
                    constraints,
                  ),
              ],
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
  DataCell _buildIconCell(IconData icon) => DataCell(Icon(icon));

  Widget _buildCookiesTable(
    BuildContext context,
    String title,
    List<Cookie> cookies,
    BoxConstraints constraints, {
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
            style: theme.textTheme.subhead,
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
    return Container(
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
