// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../common_widgets.dart';
import '../http/http.dart';
import '../http/http_request_data.dart';
import '../table.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../utils.dart';
import 'network_model.dart';

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

class HttpResponseView extends StatelessWidget {
  const HttpResponseView(this.data);

  final HttpRequestData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Text(
        data.responseBody,
        style: fixedFontStyle(context),
      ),
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
        return ListView(
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

class NetworkRequestOverviewView extends StatelessWidget {
  const NetworkRequestOverviewView(this.data);

  static const _keyWidth = 110.0;
  static const _timingGraphHeight = 18.0;
  @visibleForTesting
  static const httpTimingGraphKey = Key('Http Timing Graph Key');
  @visibleForTesting
  static const socketTimingGraphKey = Key('Socket Timing Graph Key');

  final NetworkRequest data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(defaultSpacing),
      children: [
        ..._buildGeneralRows(context),
        if (data is WebSocket) ..._buildSocketOverviewRows(context),
        const PaddedDivider(
          padding: EdgeInsets.only(bottom: denseRowSpacing),
        ),
        ..._buildTimingOverview(context),
      ],
    );
  }

  List<Widget> _buildGeneralRows(BuildContext context) {
    return [
      // TODO(kenz): show preview for requests (png, response body, proto)
      _buildRow(
        context: context,
        title: 'Request uri',
        child: _valueText(data.uri),
      ),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'Method',
        child: _valueText(data.method),
      ),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'Status',
        child: _valueText(data.status ?? '--'),
      ),
      const SizedBox(height: defaultSpacing),
      if (data.port != null) ...[
        _buildRow(
          context: context,
          title: 'Port',
          child: _valueText('${data.port}'),
        ),
        const SizedBox(height: defaultSpacing),
      ],
      if (data.contentType != null) ...[
        _buildRow(
          context: context,
          title: 'Content type',
          child: _valueText(data.contentType ?? 'null'),
        ),
        const SizedBox(height: defaultSpacing),
      ],
    ];
  }

  List<Widget> _buildTimingOverview(BuildContext context) {
    return [
      _buildRow(
        context: context,
        title: 'Timing',
        child: data is WebSocket
            ? _buildSocketTimeGraph(context)
            : _buildHttpTimeGraph(context),
      ),
      const SizedBox(height: denseSpacing),
      _buildRow(
        context: context,
        title: null,
        child: _valueText(data.durationDisplay),
      ),
      const SizedBox(height: defaultSpacing),
      ...data is WebSocket
          ? _buildSocketTimingRows(context)
          : _buildHttpTimingRows(context),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'Start time',
        child: _valueText(formatDateTime(data.startTimestamp)),
      ),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'End time',
        child: _valueText(data.endTimestamp != null
            ? formatDateTime(data.endTimestamp)
            : 'Pending'),
      ),
    ];
  }

  Widget _buildHttpTimeGraph(BuildContext context) {
    final data = this.data as HttpRequestData;
    if (data.duration == null || data.instantEvents.isEmpty) {
      return Container(
        key: httpTimingGraphKey,
        height: 18.0,
        color: mainRasterColor,
      );
    }

    final _colors = [
      searchMatchColor,
      mainRasterColor,
    ];
    var _colorIndex = 0;
    Color _nextColor() {
      final color = _colors[_colorIndex % _colors.length];
      _colorIndex++;
      return color;
    }

    // TODO(kenz): consider calculating these sizes by hand instead of using
    // flex so that we can set a minimum width for small timing chunks.
    final timingWidgets = <Widget>[];
    for (final instant in data.instantEvents) {
      final duration = instant.timeRange.duration;
      final flex =
          (duration.inMicroseconds / data.duration.inMicroseconds * 100)
              .round();
      timingWidgets.add(
        Flexible(
          flex: flex,
          child: Tooltip(
            waitDuration: tooltipWait,
            message: '${instant.name} - ${msText(duration)}',
            child: Container(
              height: _timingGraphHeight,
              color: _nextColor(),
            ),
          ),
        ),
      );
    }
    return Row(
      key: httpTimingGraphKey,
      children: timingWidgets,
    );
  }

  // TODO(kenz): add a "waterfall" like visualization with the same colors that
  // are used in the timing graph.
  List<Widget> _buildHttpTimingRows(BuildContext context) {
    final data = this.data as HttpRequestData;
    return [
      for (final instant in data.instantEvents) ...[
        _buildRow(
          context: context,
          title: instant.name,
          child: _valueText(
              '[${msText(instant.timeRange.start - data.instantEvents.first.timeRange.start)} - '
              '${msText(instant.timeRange.end - data.instantEvents.first.timeRange.start)}]'
              ' → ${msText(instant.timeRange.duration)} total'),
        ),
        if (instant != data.instantEvents.last)
          const SizedBox(height: defaultSpacing),
      ]
    ];
  }

  List<Widget> _buildSocketOverviewRows(BuildContext context) {
    final socket = data as WebSocket;
    return [
      _buildRow(
        context: context,
        title: 'Socket id',
        child: _valueText('${socket.id}'),
      ),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'Socket type',
        child: _valueText(socket.socketType),
      ),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'Read bytes',
        child: _valueText('${socket.readBytes}'),
      ),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'Write bytes',
        child: _valueText('${socket.writeBytes}'),
      ),
      const SizedBox(height: defaultSpacing),
    ];
  }

  Widget _buildSocketTimeGraph(BuildContext context) {
    return Container(
      key: socketTimingGraphKey,
      height: _timingGraphHeight,
      color: mainUiColor,
    );
  }

  List<Widget> _buildSocketTimingRows(BuildContext context) {
    final data = this.data as WebSocket;
    return [
      _buildRow(
        context: context,
        title: 'Last read time',
        child: data.lastReadTimestamp != null
            ? _valueText(formatDateTime(data.lastReadTimestamp))
            : '--',
      ),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'Last write time',
        child: _valueText(formatDateTime(data.lastWriteTimestamp)),
      ),
    ];
  }

  Widget _buildRow({
    @required BuildContext context,
    @required String title,
    @required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _keyWidth,
          child: Text(
            title != null ? '$title: ' : '',
            style: Theme.of(context).textTheme.subtitle2,
          ),
        ),
        Expanded(
          child: child,
        ),
      ],
    );
  }

  Widget _valueText(String value) {
    return Text(
      value,
      overflow: TextOverflow.ellipsis,
      maxLines: 5,
    );
  }
}
