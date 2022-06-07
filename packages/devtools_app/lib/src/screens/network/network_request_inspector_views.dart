// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import '../../http/http.dart';
import '../../http/http_request_data.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/table.dart';
import '../../shared/theme.dart';
import '../../ui/colors.dart';
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
  Key? key,
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

  final DartIOHttpRequestData data;

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
          SelectableText(
            '$key: ',
            style: Theme.of(context).textTheme.subtitle2,
          ),
          Expanded(
            child: SelectableText(
              value,
              minLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final general = data.general;
    final responseHeaders = data.responseHeaders;
    final requestHeaders = data.requestHeaders;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          children: [
            _buildTile(
              'General',
              [
                for (final entry in general.entries)
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
                if (responseHeaders != null)
                  for (final entry in responseHeaders.entries)
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
                if (requestHeaders != null)
                  for (final entry in requestHeaders.entries)
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

class HttpRequestView extends StatelessWidget {
  const HttpRequestView(this.data);

  final DartIOHttpRequestData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: SingleChildScrollView(
        child: JsonViewer(encodedJson: data.requestBody!),
      ),
    );
  }
}

class HttpResponseView extends StatelessWidget {
  const HttpResponseView(this.data);

  final DartIOHttpRequestData data;

  @override
  Widget build(BuildContext context) {
    Widget child;
    final theme = Theme.of(context);
    // We shouldn't try and display an image response view when using the
    // timeline profiler since it's possible for response body data to get
    // dropped.
    final contentType = data.contentType;
    final responseBody = data.responseBody!;
    if (contentType != null && contentType.contains('image')) {
      child = ImageResponseView(data);
    } else if (contentType != null &&
        contentType.contains('json') &&
        responseBody.isNotEmpty) {
      child = JsonViewer(encodedJson: responseBody);
    } else {
      child = Text(
        responseBody,
        style: theme.fixedFontStyle,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: SingleChildScrollView(child: child),
    );
  }
}

class ImageResponseView extends StatelessWidget {
  const ImageResponseView(this.data);

  final DartIOHttpRequestData data;

  @override
  Widget build(BuildContext context) {
    final encodedResponse = data.encodedResponse!;
    final img = image.decodeImage(encodedResponse)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTile(
          'Image Preview',
          [
            Padding(
              padding: const EdgeInsets.all(
                denseSpacing,
              ),
              child: Image.memory(
                encodedResponse,
              ),
            ),
          ],
        ),
        _buildTile(
          'Metadata',
          [
            _buildRow(
              context,
              'Format',
              data.type,
            ),
            _buildRow(
              context,
              'Size',
              prettyPrintBytes(
                encodedResponse.lengthInBytes,
                includeUnit: true,
              )!,
            ),
            _buildRow(
              context,
              'Dimensions',
              '${img.width} x ${img.height}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    String key,
    String value,
  ) {
    return Padding(
      padding: _rowPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            '$key: ',
            style: Theme.of(context).textTheme.subtitle2,
          ),
          Expanded(
            child: SelectableText(
              value,
              // TODO(kenz): use top level overflow parameter if
              // https://github.com/flutter/flutter/issues/82722 is fixed.
              // TODO(kenz): add overflow after flutter 2.3.0 is stable. It was
              // added in commit 65388ee2eeaf0d2cf087eaa4a325e3689020c46a.
              // style: const TextStyle(overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
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

  final DartIOHttpRequestData data;

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
          _buildCell(cookie.value!.length.toString()),
          _buildIconCell(!cookie.httpOnly ? Icons.check : Icons.close),
          _buildIconCell(!cookie.secure ? Icons.check : Icons.close),
        ],
      ],
    );
  }

  DataCell _buildCell(String? value) => DataCell(SelectableText(value ?? '--'));

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
          child: SelectableText(
            title,
            // TODO(kenz): use top level overflow parameter if
            // https://github.com/flutter/flutter/issues/82722 is fixed.
            // TODO(kenz): add overflow after flutter 2.3.0 is stable. It was
            // added in commit 65388ee2eeaf0d2cf087eaa4a325e3689020c46a.
            // style: theme.textTheme.subtitle1.copyWith(
            //   overflow: TextOverflow.fade,
            // ),
            style: theme.textTheme.subtitle1,
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
        title: '',
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
        child: _valueText(formatDateTime(data.startTimestamp!)),
      ),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'End time',
        child: _valueText(
          data.endTimestamp != null
              ? formatDateTime(data.endTimestamp!)
              : 'Pending',
        ),
      ),
    ];
  }

  Widget _buildTimingRow(
    Color color,
    String label,
    Duration duration,
  ) {
    final flex =
        (duration.inMicroseconds / data.duration!.inMicroseconds * 100).round();
    return Flexible(
      flex: flex,
      child: DevToolsTooltip(
        message: '$label - ${msText(duration)}',
        child: Container(
          height: _timingGraphHeight,
          color: color,
        ),
      ),
    );
  }

  Widget _buildHttpTimeGraph(BuildContext context) {
    final data = this.data as DartIOHttpRequestData;
    if (data.duration == null || data.instantEvents.isEmpty) {
      return Container(
        key: httpTimingGraphKey,
        height: 18.0,
        color: mainRasterColor,
      );
    }

    const _colors = [
      searchMatchColor,
      mainRasterColor,
      mainAsyncColor,
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
      final duration = instant.timeRange!.duration;
      timingWidgets.add(
        _buildTimingRow(_nextColor(), instant.name, duration),
      );
    }
    final duration = Duration(
      microseconds: data.endTimestamp!.microsecondsSinceEpoch -
          data.instantEvents.last.timestampMicros -
          data.timelineMicrosecondsSinceEpoch(0),
    );
    timingWidgets.add(
      _buildTimingRow(_nextColor(), 'Response', duration),
    );
    return Row(
      key: httpTimingGraphKey,
      children: timingWidgets,
    );
  }

  // TODO(kenz): add a "waterfall" like visualization with the same colors that
  // are used in the timing graph.
  List<Widget> _buildHttpTimingRows(BuildContext context) {
    final data = this.data as DartIOHttpRequestData;
    final result = <Widget>[];
    for (final instant in data.instantEvents) {
      final instantEventStart = data.instantEvents.first.timeRange!.start!;
      final timeRange = instant.timeRange!;
      result.addAll([
        _buildRow(
          context: context,
          title: instant.name,
          child: _valueText(
            '[${msText(timeRange.start! - instantEventStart)} - '
            '${msText(timeRange.end! - instantEventStart)}]'
            ' → ${msText(timeRange.duration)} total',
          ),
        ),
        if (instant != data.instantEvents.last)
          const SizedBox(height: defaultSpacing),
      ]);
    }
    return result;
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
    final lastReadTimestamp = data.lastReadTimestamp;
    final lastWriteTimestamp = data.lastWriteTimestamp;
    return [
      _buildRow(
        context: context,
        title: 'Last read time',
        child: lastReadTimestamp != null
            ? _valueText(formatDateTime(lastReadTimestamp))
            : _valueText('--'),
      ),
      const SizedBox(height: defaultSpacing),
      _buildRow(
        context: context,
        title: 'Last write time',
        child: lastWriteTimestamp != null
            ? _valueText(formatDateTime(lastWriteTimestamp))
            : _valueText('--'),
      ),
    ];
  }

  Widget _buildRow({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _keyWidth,
          child: SelectableText(
            title.isEmpty ? '' : '$title: ',
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
    return SelectableText(
      value,
      minLines: 1,
    );
  }
}
