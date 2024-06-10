// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import '../../shared/common_widgets.dart';
import '../../shared/http/http.dart';
import '../../shared/http/http_request_data.dart';
import '../../shared/primitives/byte_utils.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/colors.dart';
import 'network_controller.dart';
import 'network_model.dart';

// Approximately double the indent of the expandable tile's title.
const _rowIndentPadding = 30.0;

// No padding between the last element and the divider of a expandable tile.
const _rowSpacingPadding = 15.0;

const _rowPadding =
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
    initiallyExpanded: true,
    children: children,
  );
}

/// This widget displays general HTTP request / response information that is
/// contained in the headers, in addition to the standard connection information.
class HttpRequestHeadersView extends StatelessWidget {
  const HttpRequestHeadersView(this.data, {super.key});

  @visibleForTesting
  static const generalKey = Key('General');
  @visibleForTesting
  static const requestHeadersKey = Key('Request Headers');
  @visibleForTesting
  static const responseHeadersKey = Key('Response Headers');

  final DartIOHttpRequestData data;

  @override
  Widget build(BuildContext context) {
    final general = data.general;
    final responseHeaders = data.responseHeaders;
    final requestHeaders = data.requestHeaders;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SelectionArea(
          child: ListView(
            children: [
              _buildTile(
                'General',
                [
                  for (final entry in general.entries)
                    _Row(
                      entry: entry,
                      constraints: constraints,
                      isErrorValue: data.didFail && entry.key == 'statusCode',
                    ),
                ],
                key: generalKey,
              ),
              _buildTile(
                'Response Headers',
                [
                  if (responseHeaders != null)
                    for (final entry in responseHeaders.entries)
                      _Row(entry: entry, constraints: constraints),
                ],
                key: responseHeadersKey,
              ),
              _buildTile(
                'Request Headers',
                [
                  if (requestHeaders != null)
                    for (final entry in requestHeaders.entries)
                      _Row(entry: entry, constraints: constraints),
                ],
                key: requestHeadersKey,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.constraints,
    this.isErrorValue = false,
  });

  final MapEntry<String, Object?> entry;
  final BoxConstraints constraints;
  final bool isErrorValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: constraints.minWidth,
      padding: _rowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.key}: ',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Expanded(
            child: Text(
              style: isErrorValue
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
              '${entry.value}',
            ),
          ),
        ],
      ),
    );
  }
}

class HttpRequestView extends StatelessWidget {
  const HttpRequestView(this.data, {super.key});

  final DartIOHttpRequestData data;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, __) {
        final theme = Theme.of(context);
        final requestHeaders = data.requestHeaders;
        final requestContentType = requestHeaders?['content-type'] ?? '';
        final isLoading = data.isFetchingFullData;
        if (isLoading) {
          return CenteredCircularProgressIndicator(
            size: mediumProgressSize,
          );
        }

        final isJson = switch (requestContentType) {
          List() =>
            requestContentType.any((e) => (e as String).contains('json')),
          String() => requestContentType.contains('json'),
          _ => throw StateError(
              "Expected 'content-type' to be a List or String, but got: "
              '$requestContentType',
            ),
        };

        Widget child;
        child = isJson
            ? JsonViewer(encodedJson: data.requestBody!)
            : TextViewer(
                text: data.requestBody!,
                style: theme.fixedFontStyle,
              );
        return Padding(
          padding: const EdgeInsets.all(denseSpacing),
          child: SingleChildScrollView(
            child: child,
          ),
        );
      },
    );
  }
}

/// A button for copying [DartIOHttpRequestData] contents.
///
/// If there is no content to copy, the button will not show. The copy contents
/// will update as the request's data is updated.
class HttpViewTrailingCopyButton extends StatelessWidget {
  const HttpViewTrailingCopyButton(this.data, this.dataSelector, {super.key});
  final DartIOHttpRequestData data;
  final String? Function(DartIOHttpRequestData) dataSelector;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, __) {
        final dataToCopy = dataSelector(data);
        final isLoading = data.isFetchingFullData;
        if (dataToCopy == null || dataToCopy.isEmpty || isLoading) {
          return Container();
        }

        return Align(
          alignment: Alignment.centerRight,
          child: CopyToClipboardControl(
            dataProvider: () => dataToCopy,
          ),
        );
      },
    );
  }
}

/// A DropDownButton for selecting [NetworkResponseViewType].
///
/// If there is no content to visualise, the drop down will not show. Drop down
/// values will update as the request's data is updated.
class HttpResponseTrailingDropDown extends StatelessWidget {
  const HttpResponseTrailingDropDown(
    this.data, {
    super.key,
    required this.currentResponseViewType,
    required this.onChanged,
  });

  final ValueListenable<NetworkResponseViewType> currentResponseViewType;
  final DartIOHttpRequestData data;
  final ValueChanged<NetworkResponseViewType> onChanged;

  bool isJsonDecodable() {
    try {
      json.decode(data.responseBody!);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (_, __) {
        final visible = (data.contentType != null &&
                !data.contentType!.contains('image')) &&
            data.responseBody!.isNotEmpty;

        final availableResponseTypes = <NetworkResponseViewType>[
          NetworkResponseViewType.auto,
          if (isJsonDecodable()) NetworkResponseViewType.json,
          NetworkResponseViewType.text,
        ];

        return Visibility(
          visible: visible,
          replacement: const SizedBox(),
          child: ValueListenableBuilder<NetworkResponseViewType>(
            valueListenable: currentResponseViewType,
            builder: (_, currentType, __) {
              return RoundedDropDownButton<NetworkResponseViewType>(
                value: currentType,
                items: availableResponseTypes
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toString()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  onChanged(value);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class HttpResponseView extends StatelessWidget {
  const HttpResponseView(
    this.data, {
    super.key,
    required this.currentResponseViewType,
  });

  final DartIOHttpRequestData data;
  final ValueListenable<NetworkResponseViewType> currentResponseViewType;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, __) {
        Widget child;
        final theme = Theme.of(context);
        // We shouldn't try and display an image response view when using the
        // timeline profiler since it's possible for response body data to get
        // dropped.
        final contentType = data.contentType;
        final responseBody = data.responseBody!;
        final isLoading = data.isFetchingFullData;
        if (isLoading) {
          return CenteredCircularProgressIndicator(
            size: mediumProgressSize,
          );
        }
        if (contentType != null && contentType.contains('image')) {
          child = ImageResponseView(data);
        } else {
          child = HttpTextResponseViewer(
            contentType: contentType,
            responseBody: responseBody,
            currentResponseNotifier: currentResponseViewType,
            textStyle: theme.fixedFontStyle,
          );
        }
        return Padding(
          padding: const EdgeInsets.all(denseSpacing),
          child: SingleChildScrollView(child: child),
        );
      },
    );
  }
}

class HttpTextResponseViewer extends StatelessWidget {
  const HttpTextResponseViewer({
    super.key,
    required this.contentType,
    required this.responseBody,
    required this.currentResponseNotifier,
    required this.textStyle,
  });

  final String? contentType;
  final String responseBody;
  final ValueListenable<NetworkResponseViewType> currentResponseNotifier;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentResponseNotifier,
      builder: (_, currentResponseType, __) {
        NetworkResponseViewType currentLocalResponseType = currentResponseType;

        if (currentResponseType == NetworkResponseViewType.auto) {
          if (contentType != null &&
              contentType!.contains('json') &&
              responseBody.isNotEmpty) {
            currentLocalResponseType = NetworkResponseViewType.json;
          } else {
            currentLocalResponseType = NetworkResponseViewType.text;
          }
        }

        return switch (currentLocalResponseType) {
          NetworkResponseViewType.json => JsonViewer(encodedJson: responseBody),
          NetworkResponseViewType.text => TextViewer(
              text: responseBody,
              style: textStyle,
            ),
          _ => const SizedBox(),
        };
      },
    );
  }
}

class ImageResponseView extends StatelessWidget {
  const ImageResponseView(this.data, {super.key});

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
          Text(
            '$key: ',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Expanded(
            child: Text(
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
  const HttpRequestCookiesView(this.data, {super.key});

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

  DataCell _buildCell(String? value) => DataCell(Text(value ?? '--'));

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
    DataColumn buildColumn(
      String title, {
      bool numeric = false,
    }) {
      return DataColumn(
        label: Expanded(
          child: Text(
            title,
            // TODO(kenz): use top level overflow parameter if
            // https://github.com/flutter/flutter/issues/82722 is fixed.
            // TODO(kenz): add overflow after flutter 2.3.0 is stable. It was
            // added in commit 65388ee2eeaf0d2cf087eaa4a325e3689020c46a.
            // style: theme.textTheme.titleMedium.copyWith(
            //   overflow: TextOverflow.fade,
            // ),
            style: theme.textTheme.titleMedium,
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
                dataRowMinHeight: defaultRowHeight,
                dataRowMaxHeight: defaultRowHeight,
                // NOTE: if this list of columns change, _buildRow will need
                // to be updated to match.
                columns: [
                  buildColumn('Name'),
                  buildColumn('Value'),
                  if (!requestCookies) ...[
                    buildColumn('Domain'),
                    buildColumn('Path'),
                    buildColumn('Expires / Max Age'),
                    buildColumn('Size', numeric: true),
                    buildColumn('HttpOnly'),
                    buildColumn('Secure'),
                  ],
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
  const NetworkRequestOverviewView(this.data, {super.key});

  static const _keyWidth = 110.0;
  static const _timingGraphHeight = 18.0;
  @visibleForTesting
  static const httpTimingGraphKey = Key('Http Timing Graph Key');
  @visibleForTesting
  static const socketTimingGraphKey = Key('Socket Timing Graph Key');

  final NetworkRequest data;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(defaultSpacing),
        children: [
          ..._buildGeneralRows(context),
          if (data is WebSocket) ..._buildSocketOverviewRows(context),
          const PaddedDivider(
            padding: EdgeInsets.only(bottom: denseRowSpacing),
          ),
          ..._buildTimingOverview(context),
        ],
      ),
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
        child: _valueText(
          data.status ?? '--',
          data.didFail
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
        ),
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
            : _buildHttpTimeGraph(),
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
        message: '$label - ${durationText(duration)}',
        child: Container(
          height: _timingGraphHeight,
          color: color,
        ),
      ),
    );
  }

  Widget _buildHttpTimeGraph() {
    final data = this.data as DartIOHttpRequestData;
    if (data.duration == null || data.instantEvents.isEmpty) {
      return Container(
        key: httpTimingGraphKey,
        height: 18.0,
        color: mainRasterColor,
      );
    }

    const colors = [
      searchMatchColor,
      mainRasterColor,
      mainAsyncColor,
    ];

    var colorIndex = 0;
    Color nextColor() {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return color;
    }

    // TODO(kenz): consider calculating these sizes by hand instead of using
    // flex so that we can set a minimum width for small timing chunks.
    final timingWidgets = <Widget>[];
    for (final instant in data.instantEvents) {
      final duration = instant.timeRange!.duration;
      timingWidgets.add(
        _buildTimingRow(nextColor(), instant.name, duration),
      );
    }
    final duration = Duration(
      microseconds: data.endTimestamp!.microsecondsSinceEpoch -
          data.instantEvents.last.timestamp.microsecondsSinceEpoch,
    );
    timingWidgets.add(
      _buildTimingRow(nextColor(), 'Response', duration),
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
      final startDisplay = durationText(
        timeRange.start! - instantEventStart,
        unit: DurationDisplayUnit.milliseconds,
      );
      final endDisplay = durationText(
        timeRange.end! - instantEventStart,
        unit: DurationDisplayUnit.milliseconds,
      );
      final totalDisplay = durationText(
        timeRange.duration,
        unit: DurationDisplayUnit.milliseconds,
      );
      result.addAll([
        _buildRow(
          context: context,
          title: instant.name,
          child: _valueText(
            '[$startDisplay - $endDisplay] → $totalDisplay total',
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
        child: _valueText(socket.id),
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
      color: Theme.of(context).colorScheme.primary,
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
        SizedBox(
          width: _keyWidth,
          child: Text(
            title.isEmpty ? '' : '$title: ',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: child,
        ),
      ],
    );
  }

  Widget _valueText(String value, [TextStyle? style]) {
    return Text(
      style: style,
      value,
    );
  }
}
