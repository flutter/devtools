// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:recase/recase.dart';

import '../http.dart';
import '../http_request_data.dart';

/// This widget displays general HTTP request / response information that is
/// contained in the headers, in addition to the standard connection information.
class HttpRequestHeadersView extends StatelessWidget {
  const HttpRequestHeadersView(this.data);

  final HttpRequestData data;

  ExpansionTile _buildTile(String title, List<Widget> children) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      children: children,
      initiallyExpanded: true,
    );
  }

  Widget _buildRow(String key, dynamic value, constraints) {
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
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
              'General',
              [
                for (final entry in data.general.entries)
                  _buildRow(
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

  static const _headerTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  DataColumn _buildColumn(String title, {bool numeric = false}) {
    return DataColumn(
      label: Expanded(
        child: Text(
          title ?? '--',
          style: _headerTextStyle,
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
    String title,
    List<Cookie> cookies,
    BoxConstraints constraints, {
    bool requestCookies = false,
  }) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.lightBlue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
    return (requestCookies.isEmpty && responseCookies.isEmpty)
        ? const Center(
            child: Text(
              'No Cookies',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
          )
        : Container(
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
                        'Response Cookies',
                        responseCookies,
                        constraints,
                      ),
                    if (requestCookies.isNotEmpty)
                      _buildCookiesTable(
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

  ExpansionTile _buildTile(String title, List<Widget> children) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      children: children,
      initiallyExpanded: true,
    );
  }

  Widget _buildRow(String key, dynamic value) {
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
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
      final timeDiffMillis = instant.timeDiffMs;
      events.add(
        _buildTile(
          instant.name,
          [
            _buildRow('Duration', '$timeDiffMillis ms'),
          ],
        ),
      );
    }
    events.add(
      _buildTile(
        'Total',
        [
          _buildRow('Duration', '${data.durationMs} ms'),
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
