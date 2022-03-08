// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:convert';
import 'dart:html' as html;

import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/screen.dart';
import '../../shared/split.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/filter.dart';
import '../../ui/search.dart';
import 'network_controller.dart';
import 'network_model.dart';
import 'network_request_inspector.dart';

final networkSearchFieldKey = GlobalKey(debugLabel: 'NetworkSearchFieldKey');

class NetworkScreen extends Screen {
  const NetworkScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          title: 'Network',
          icon: Icons.network_check,
        );

  static const id = 'network';

  @override
  String get docPageId => screenId;

  @override
  Widget build(BuildContext context) => const NetworkScreenBody();

  @override
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    final networkController = Provider.of<NetworkController>(context);
    final color = Theme.of(context).textTheme.bodyText2.color;

    return DualValueListenableBuilder<NetworkRequests, List<NetworkRequest>>(
      firstListenable: networkController.requests,
      secondListenable: networkController.filteredData,
      builder: (context, networkRequests, filteredRequests, child) {
        final filteredCount = filteredRequests.length;
        final totalCount = networkRequests.requests.length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Showing ${nf.format(filteredCount)} of '
              '${nf.format(totalCount)} '
              '${pluralize('request', totalCount)}',
            ),
            const SizedBox(width: denseSpacing),
            child,
          ],
        );
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: networkController.recordingNotifier,
        builder: (context, recording, _) {
          return SizedBox(
            width: smallProgressSize,
            height: smallProgressSize,
            child: recording
                ? SmallCircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  )
                : const SizedBox(),
          );
        },
      ),
    );
  }
}

class NetworkScreenBody extends StatefulWidget {
  const NetworkScreenBody();

  static const filterQueryInstructions = '''
Type a filter query to show or hide specific requests.

Any text that is not paired with an available filter key below will be queried against all categories (method, uri, status, type).

Available filters:
    'method', 'm'       (e.g. 'm:get', '-m:put,patch')
    'status', 's'           (e.g. 's:200', '-s:404')
    'type', 't'               (e.g. 't:json', '-t:ws')

Example queries:
    'my-endpoint method:put,post -status:404 type:json'
    'example.com -m:get s:200,201 t:htm,html,json'
    'http s:404'
    'POST'
''';

  @override
  State<StatefulWidget> createState() => _NetworkScreenBodyState();
}

class _NetworkScreenBodyState extends State<NetworkScreenBody>
    with AutoDisposeMixin {
  NetworkController _networkController;

  @override
  void initState() {
    super.initState();
    ga.screen(NetworkScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<NetworkController>(context);
    if (newController == _networkController) return;

    _networkController = newController;
    _networkController.startRecording();
  }

  @override
  void dispose() {
    // TODO(kenz): this won't work well if we eventually have multiple clients
    // that want to listen to network data.
    _networkController?.stopRecording();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NetworkProfilerControls(controller: _networkController),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: _NetworkProfilerBody(controller: _networkController),
        ),
      ],
    );
  }
}

/// The row of controls that control the Network profiler (e.g., record, pause,
/// clear, search, filter, etc.).
class _NetworkProfilerControls extends StatefulWidget {
  const _NetworkProfilerControls({
    Key key,
    @required this.controller,
  }) : super(key: key);

  static const _includeTextWidth = 810.0;

  final NetworkController controller;

  @override
  State<_NetworkProfilerControls> createState() =>
      _NetworkProfilerControlsState();
}

class _NetworkProfilerControlsState extends State<_NetworkProfilerControls>
    with AutoDisposeMixin, SearchFieldMixin<_NetworkProfilerControls> {
  NetworkRequests requests;

  List<NetworkRequest> filteredRequests;

  bool recording;

  @override
  void initState() {
    super.initState();

    recording = widget.controller.recordingNotifier.value;
    addAutoDisposeListener(widget.controller.recordingNotifier, () {
      setState(() {
        recording = widget.controller.recordingNotifier.value;
      });
    });
    requests = widget.controller.requests.value;
    addAutoDisposeListener(widget.controller.requests, () {
      setState(() {
        requests = widget.controller.requests.value;
      });
    });
    filteredRequests = widget.controller.filteredData.value;
    addAutoDisposeListener(widget.controller.filteredData, () {
      setState(() {
        filteredRequests = widget.controller.filteredData.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasRequests = filteredRequests.isNotEmpty;
    return Row(
      children: [
        PauseButton(
          minScreenWidthForTextBeforeScaling:
              _NetworkProfilerControls._includeTextWidth,
          tooltip: 'Pause recording network traffic',
          onPressed: recording
              ? () {
                  ga.select(
                    analytics_constants.network,
                    analytics_constants.pause,
                  );
                  widget.controller.togglePolling(false);
                }
              : null,
        ),
        const SizedBox(width: denseSpacing),
        ResumeButton(
          minScreenWidthForTextBeforeScaling:
              _NetworkProfilerControls._includeTextWidth,
          tooltip: 'Resume recording network traffic',
          onPressed: recording
              ? null
              : () {
                  ga.select(
                    analytics_constants.network,
                    analytics_constants.resume,
                  );
                  widget.controller.togglePolling(true);
                },
        ),
        const SizedBox(width: denseSpacing),
        ClearButton(
          minScreenWidthForTextBeforeScaling:
              _NetworkProfilerControls._includeTextWidth,
          onPressed: () {
            ga.select(
              analytics_constants.network,
              analytics_constants.clear,
            );
            widget.controller.clear();
          },
        ),
        const SizedBox(width: denseSpacing),
        ExportNetButton(
          minScreenWidthForTextBeforeScaling:
              _NetworkProfilerControls._includeTextWidth,
          onPressed: () {
            final reqs =
                widget.controller.filteredData.value.cast<HttpRequestData>();
            Map<String, dynamic> har = {
              'log': {
                'version': '1.2',
                'creator': {
                  'name': 'flutter_tool',
                  'version': '0.0.1',
                },
                'entries': [
                  reqs
                      .map((e) => {
                            'startedDateTime':
                                e.startTimestamp.toIso8601String(),
                            'time': e.duration.inMilliseconds,
                            'request': {
                              'method': e.method.toUpperCase(),
                              'url': e.uri.toString(),
                              'httpVersion': 'HTTP/1.1',
                              'cookies': e.requestCookies
                                  .map((e) => {
                                        'name': e.name,
                                        'value': e.value,
                                        'path': e.path,
                                        'domain': e.domain,
                                        'expires': e.expires?.toIso8601String(),
                                        'httpOnly': e.httpOnly,
                                        'secure': e.secure,
                                      })
                                  .toList(),
                              'headers': e.requestHeaders.entries
                                  .map((h) => {
                                        'name': h.key,
                                        'value': h.value,
                                      })
                                  .toList(),
                              'queryString': Uri.parse(e.uri)
                                  .queryParameters
                                  .entries
                                  .map((q) => {
                                        'name': q.key,
                                        'value': q.value,
                                      })
                                  .toList(),
                              'postData': {
                                'mimeType': e.contentType,
                                'text': e.requestBody,
                              },
                              'headersSize': -1,
                              'bodySize': -1,
                            },
                            'response': {
                              'status': e.status,
                              'statusText': e.status,
                              'httpVersion': 'HTTP/1.1',
                              'cookies': e.responseCookies
                                  .map((e) => {
                                        'name': e.name,
                                        'value': e.value,
                                        'path': e.path,
                                        'domain': e.domain,
                                        'expires': e.expires?.toIso8601String(),
                                        'httpOnly': e.httpOnly,
                                        'secure': e.secure,
                                      })
                                  .toList(),
                              'headers': e.responseHeaders.entries
                                  .map((h) => {
                                        'name': h.key,
                                        'value': h.value,
                                      })
                                  .toList(),
                              'content': {
                                'size': e.responseBody.length,
                                'mimeType': e.type,
                                'text': e.responseBody,
                              },
                              'redirectURL': '',
                              'headersSize': -1,
                              'bodySize': -1,
                            },
                            'cache': {},
                            'timings': {},
                            'serverIPAddress': '10.0.0.1',
                            'connection': e.hashCode.toString(),
                            'comment': ''
                          })
                      .toList()
                ],
              },
            };
            html.AnchorElement()
              ..href =
                  '${Uri.dataFromString(json.encode(har), mimeType: 'text/plain', encoding: utf8)}'
              ..download = 'network.har'
              ..style.display = 'none'
              ..click();
            widget.controller.clear();
          },
        ),
        const SizedBox(width: defaultSpacing),
        const Expanded(child: SizedBox()),
        // TODO(kenz): fix focus issue when state is refreshed
        Container(
          width: wideSearchTextWidth,
          height: defaultTextFieldHeight,
          child: buildSearchField(
            controller: widget.controller,
            searchFieldKey: networkSearchFieldKey,
            searchFieldEnabled: hasRequests,
            shouldRequestFocus: false,
            supportsNavigation: true,
          ),
        ),
        const SizedBox(width: denseSpacing),
        FilterButton(
          onPressed: _showFilterDialog,
          isFilterActive: filteredRequests.length != requests.requests.length,
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog<NetworkController, NetworkRequest>(
        controller: widget.controller,
        queryInstructions: NetworkScreenBody.filterQueryInstructions,
        queryFilterArguments: widget.controller.filterArgs,
      ),
    );
  }
}

class _NetworkProfilerBody extends StatelessWidget {
  const _NetworkProfilerBody({Key key, this.controller}) : super(key: key);

  final NetworkController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context)?.unfocus(),
      child: Split(
        initialFractions: const [0.5, 0.5],
        minSizes: const [200, 200],
        axis: Axis.horizontal,
        children: [
          ValueListenableBuilder(
            valueListenable: controller.filteredData,
            builder: (context, filteredRequests, _) {
              return NetworkRequestsTable(
                networkController: controller,
                requests: filteredRequests,
                searchMatchesNotifier: controller.searchMatches,
                activeSearchMatchNotifier: controller.activeSearchMatch,
              );
            },
          ),
          NetworkRequestInspector(controller),
        ],
      ),
    );
  }
}

class NetworkRequestsTable extends StatelessWidget {
  const NetworkRequestsTable({
    Key key,
    @required this.networkController,
    @required this.requests,
    @required this.searchMatchesNotifier,
    @required this.activeSearchMatchNotifier,
  }) : super(key: key);

  static MethodColumn methodColumn = MethodColumn();
  static UriColumn addressColumn = UriColumn();
  static StatusColumn statusColumn = StatusColumn();
  static TypeColumn typeColumn = TypeColumn();
  static DurationColumn durationColumn = DurationColumn();
  static TimestampColumn timestampColumn = TimestampColumn();

  final NetworkController networkController;
  final List<NetworkRequest> requests;
  final ValueListenable<List<NetworkRequest>> searchMatchesNotifier;
  final ValueListenable<NetworkRequest> activeSearchMatchNotifier;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration(
      child: FlatTable<NetworkRequest>(
        columns: [
          methodColumn,
          addressColumn,
          statusColumn,
          typeColumn,
          durationColumn,
          timestampColumn,
        ],
        data: requests,
        keyFactory: (NetworkRequest data) => ValueKey<NetworkRequest>(data),
        onItemSelected: (item) {
          networkController.selectRequest(item);
        },
        selectionNotifier: networkController.selectedRequest,
        autoScrollContent: true,
        sortColumn: timestampColumn,
        sortDirection: SortDirection.ascending,
        searchMatchesNotifier: searchMatchesNotifier,
        activeSearchMatchNotifier: activeSearchMatchNotifier,
      ),
    );
  }
}

class UriColumn extends ColumnData<NetworkRequest>
    implements ColumnRenderer<NetworkRequest> {
  UriColumn()
      : super.wide(
          'Uri',
          minWidthPx: scaleByFontFactor(100.0),
        );

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.uri;
  }

  @override
  Widget build(
    BuildContext context,
    NetworkRequest data, {
    bool isRowSelected = false,
    VoidCallback onPressed,
  }) {
    final value = getDisplayValue(data);

    return SelectableText(
      value,
      maxLines: 1,
      style: const TextStyle(overflow: TextOverflow.ellipsis),
      // [onPressed] needs to be passed along to [SelectableText] so that a
      // click on the text will still trigger the [onPressed] action for the
      // row.
      onTap: onPressed,
    );
  }
}

class MethodColumn extends ColumnData<NetworkRequest> {
  MethodColumn() : super('Method', fixedWidthPx: scaleByFontFactor(70));

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.method;
  }
}

class StatusColumn extends ColumnData<NetworkRequest>
    implements ColumnRenderer<NetworkRequest> {
  StatusColumn()
      : super(
          'Status',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(62),
        );

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.status;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return dataObject.status == null ? '--' : dataObject.status.toString();
  }

  @override
  Widget build(
    BuildContext context,
    NetworkRequest data, {
    bool isRowSelected = false,
    VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Text(
      getDisplayValue(data),
      style: data.didFail
          ? theme.regularTextStyle.copyWith(color: devtoolsError)
          : theme.regularTextStyle,
    );
  }
}

class TypeColumn extends ColumnData<NetworkRequest> {
  TypeColumn()
      : super(
          'Type',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(62),
        );

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.type;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return dataObject.type == null ? '--' : dataObject.type;
  }
}

class DurationColumn extends ColumnData<NetworkRequest> {
  DurationColumn()
      : super(
          'Duration',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(80),
        );

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.duration?.inMilliseconds;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    final ms = getValue(dataObject);
    return ms == null
        ? 'Pending'
        : msText(
            Duration(milliseconds: ms),
            fractionDigits: 0,
          );
  }
}

class TimestampColumn extends ColumnData<NetworkRequest> {
  TimestampColumn()
      : super(
          'Timestamp',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(135),
        );

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.startTimestamp;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return formatDateTime(dataObject.startTimestamp);
  }
}
