// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/table.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../http/http_request_data.dart';
import '../../table_data.dart';
import '../../utils.dart';
import '../network_controller.dart';
import 'http_request_inspector.dart';

class NetworkScreen extends Screen {
  const NetworkScreen()
      : super('network', title: 'Network', icon: Icons.network_check);

  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const stopButtonKey = Key('Stop Button');
  @visibleForTesting
  static const recordButtonKey = Key('Record Button');
  @visibleForTesting
  static const recordingInstructionsKey = Key('Recording Instructions');

  @override
  Widget build(BuildContext context) {
    return !serviceManager.connectedApp.isDartWebAppNow
        ? const NetworkScreenBody()
        : const DisabledForWebAppMessage();
  }

  @override
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    final networkController = Provider.of<NetworkController>(context);
    final color = Theme.of(context).textTheme.bodyText2.color;

    return ValueListenableBuilder<bool>(
      valueListenable: networkController.recordingNotifier,
      builder: (context, recording, _) {
        return ValueListenableBuilder<HttpRequests>(
          valueListenable: networkController.requests,
          builder: (context, httpRequests, _) {
            final count = httpRequests.requests.length;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${nf.format(count)} ${pluralize('request', count)}'),
                const SizedBox(width: denseSpacing),
                SizedBox(
                  width: smallProgressSize,
                  height: smallProgressSize,
                  child: recording
                      ? CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        )
                      : const SizedBox(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class NetworkScreenBody extends StatefulWidget {
  const NetworkScreenBody();

  @override
  State<StatefulWidget> createState() => _NetworkScreenBodyState();
}

class _NetworkScreenBodyState extends State<NetworkScreenBody> {
  NetworkController _networkController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<NetworkController>(context);
    if (newController == _networkController) return;

    _networkController?.removeClient();

    _networkController = newController;
    _networkController.addClient();
  }

  @override
  void dispose() {
    _networkController?.removeClient();
    super.dispose();
  }

  /// Builds the row of buttons that control the HTTP profiler (e.g., record,
  /// pause, etc.)
  Row _buildHttpProfilerControlRow(bool isRecording) {
    const double includeTextWidth = 600;

    return Row(
      children: [
        recordButton(
          key: NetworkScreen.recordButtonKey,
          recording: isRecording,
          labelOverride: 'Record HTTP traffic',
          includeTextWidth: includeTextWidth,
          onPressed: _networkController.startRecording,
        ),
        const SizedBox(width: denseSpacing),
        stopButton(
          key: NetworkScreen.stopButtonKey,
          paused: !isRecording,
          includeTextWidth: includeTextWidth,
          onPressed: _networkController.stopRecording,
        ),
        const Expanded(child: SizedBox(width: denseSpacing)),
        clearButton(
          key: NetworkScreen.clearButtonKey,
          onPressed: () {
            _networkController.clear();
          },
        ),
      ],
    );
  }

  Widget _buildHttpProfilerBody(
      List<HttpRequestData> requests, bool isRecording) {
    return ValueListenableBuilder<HttpRequestData>(
      valueListenable: _networkController.selectedHttpRequest,
      builder: (context, selectedHttpRequest, _) {
        return Expanded(
          child: (!isRecording && requests.isEmpty)
              ? Center(
                  child: recordingInfo(
                    instructionsKey: NetworkScreen.recordingInstructionsKey,
                    recording: isRecording,
                    // TODO(kenz): create a processing notifier if necessary
                    // for this data.
                    processing: false,
                    recordedObject: 'HTTP requests',
                    isPause: true,
                  ),
                )
              : Split(
                  initialFractions: const [0.5, 0.5],
                  minSizes: const [200, 200],
                  axis: Axis.horizontal,
                  children: [
                    HttpRequestsTable(
                      networkController: _networkController,
                      requests: requests,
                    ),
                    HttpRequestInspector(selectedHttpRequest),
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HttpRequests>(
      valueListenable: _networkController.requests,
      builder: (context, httpRequests, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _networkController.recordingNotifier,
          builder: (context, isRecording, _) {
            return Column(
              children: [
                _buildHttpProfilerControlRow(isRecording),
                const SizedBox(height: denseRowSpacing),
                _buildHttpProfilerBody(httpRequests.requests, isRecording),
              ],
            );
          },
        );
      },
    );
  }
}

class HttpRequestsTable extends StatelessWidget {
  const HttpRequestsTable({
    Key key,
    @required this.networkController,
    @required this.requests,
  }) : super(key: key);

  static MethodColumn methodColumn = MethodColumn();
  static UriColumn uriColumn = UriColumn();
  static StatusColumn statusColumn = StatusColumn();
  static DurationColumn durationColumn = DurationColumn();
  static TimestampColumn timestampColumn = TimestampColumn();

  final NetworkController networkController;
  final List<HttpRequestData> requests;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration(
      child: FlatTable<HttpRequestData>(
        columns: [
          methodColumn,
          uriColumn,
          statusColumn,
          durationColumn,
          timestampColumn,
        ],
        data: requests,
        keyFactory: (HttpRequestData data) => ValueKey<HttpRequestData>(data),
        onItemSelected: (item) {
          networkController.selectHttpRequest(item);
        },
        autoScrollContent: true,
        sortColumn: timestampColumn,
        sortDirection: SortDirection.ascending,
      ),
    );
  }
}

class UriColumn extends ColumnData<HttpRequestData>
    implements ColumnRenderer<HttpRequestData> {
  UriColumn() : super.wide('Request URI');

  @override
  dynamic getValue(HttpRequestData dataObject) {
    return dataObject.uri.toString();
  }

  @override
  Widget build(BuildContext context, HttpRequestData data) {
    final value = getDisplayValue(data);

    return Tooltip(
      message: value,
      waitDuration: tooltipWait,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class MethodColumn extends ColumnData<HttpRequestData> {
  MethodColumn() : super('Method', fixedWidthPx: 70);

  @override
  dynamic getValue(HttpRequestData dataObject) {
    return dataObject.method;
  }
}

class StatusColumn extends ColumnData<HttpRequestData> {
  StatusColumn()
      : super('Status', alignment: ColumnAlignment.right, fixedWidthPx: 62);

  @override
  dynamic getValue(HttpRequestData dataObject) {
    return dataObject.status;
  }

  @override
  String getDisplayValue(HttpRequestData dataObject) {
    return dataObject.status == null ? '--' : dataObject.status.toString();
  }
}

class DurationColumn extends ColumnData<HttpRequestData> {
  DurationColumn()
      : super('Duration', alignment: ColumnAlignment.right, fixedWidthPx: 75);

  @override
  dynamic getValue(HttpRequestData dataObject) {
    return dataObject.duration?.inMilliseconds;
  }

  // todo: test
  @override
  String getDisplayValue(HttpRequestData dataObject) {
    final ms = getValue(dataObject);
    return ms == null ? '--' : '${nf.format(ms)} ms';
  }
}

class TimestampColumn extends ColumnData<HttpRequestData> {
  TimestampColumn()
      : super('Timestamp', alignment: ColumnAlignment.right, fixedWidthPx: 165);

  @override
  dynamic getValue(HttpRequestData dataObject) {
    return dataObject.requestTime;
  }

  @override
  String getDisplayValue(HttpRequestData dataObject) {
    return formatRequestTime(dataObject.requestTime);
  }

  @visibleForTesting
  static String formatRequestTime(DateTime requestTime) {
    return DateFormat.Hms().add_yMd().format(requestTime);
  }
}
