// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../screen.dart';
import '../split.dart';
import '../table.dart';
import '../table_data.dart';
import '../theme.dart';
import '../utils.dart';
import 'network_controller.dart';
import 'network_model.dart';
import 'network_request_inspector.dart';

class NetworkScreen extends Screen {
  const NetworkScreen()
      : super.conditional(
          id: 'network',
          requiresDartVm: true,
          title: 'Network',
          icon: Icons.network_check,
        );

  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const stopButtonKey = Key('Stop Button');
  @visibleForTesting
  static const recordButtonKey = Key('Record Button');
  @visibleForTesting
  static const recordingInstructionsKey = Key('Recording Instructions');

  @override
  Widget build(BuildContext context) => const NetworkScreenBody();

  @override
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    final networkController = Provider.of<NetworkController>(context);
    final color = Theme.of(context).textTheme.bodyText2.color;

    return ValueListenableBuilder<bool>(
      valueListenable: networkController.recordingNotifier,
      builder: (context, recording, _) {
        return ValueListenableBuilder<NetworkRequests>(
          valueListenable: networkController.requests,
          builder: (context, networkRequests, _) {
            final count = networkRequests.requests.length;

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

class _NetworkScreenBodyState extends State<NetworkScreenBody>
    with AutoDisposeMixin {
  NetworkController _networkController;

  bool recording;

  NetworkRequests requests;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<NetworkController>(context);
    if (newController == _networkController) return;

    _networkController?.removeClient();

    _networkController = newController;
    _networkController.addClient();

    requests = _networkController.requests.value;
    addAutoDisposeListener(_networkController.requests, () {
      setState(() {
        requests = _networkController.requests.value;
      });
    });
    recording = _networkController.recordingNotifier.value;
    addAutoDisposeListener(_networkController.recordingNotifier, () {
      setState(() {
        recording = _networkController.recordingNotifier.value;
      });
    });
  }

  @override
  void dispose() {
    _networkController?.removeClient();
    super.dispose();
  }

  /// Builds the row of buttons that control the Network profiler (e.g., record,
  /// pause, etc.)
  Row _buildProfilerControls() {
    const double includeTextWidth = 600;

    return Row(
      children: [
        recordButton(
          key: NetworkScreen.recordButtonKey,
          recording: recording,
          labelOverride: 'Record network traffic',
          includeTextWidth: includeTextWidth,
          onPressed: _networkController.startRecording,
        ),
        const SizedBox(width: denseSpacing),
        stopRecordingButton(
          key: NetworkScreen.stopButtonKey,
          recording: recording,
          includeTextWidth: includeTextWidth,
          onPressed: _networkController.stopRecording,
        ),
        const SizedBox(width: denseSpacing),
        clearButton(
          key: NetworkScreen.clearButtonKey,
          onPressed: () {
            _networkController.clear();
          },
        ),
      ],
    );
  }

  Widget _buildProfilerBody(List<NetworkRequest> requests) {
    return ValueListenableBuilder<NetworkRequest>(
      valueListenable: _networkController.selectedRequest,
      builder: (context, selectedRequest, _) {
        return Expanded(
          child: (!recording && requests.isEmpty)
              ? Center(
                  child: recordingInfo(
                    instructionsKey: NetworkScreen.recordingInstructionsKey,
                    recording: recording,
                    // TODO(kenz): create a processing notifier if necessary
                    // for this data.
                    processing: false,
                    recordedObject: 'network traffic',
                    isPause: true,
                  ),
                )
              : Split(
                  initialFractions: const [0.5, 0.5],
                  minSizes: const [200, 200],
                  axis: Axis.horizontal,
                  children: [
                    NetworkRequestsTable(
                      networkController: _networkController,
                      requests: requests,
                    ),
                    NetworkRequestInspector(selectedRequest),
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildProfilerControls(),
        const SizedBox(height: denseRowSpacing),
        _buildProfilerBody(requests.requests),
      ],
    );
  }
}

class NetworkRequestsTable extends StatelessWidget {
  const NetworkRequestsTable({
    Key key,
    @required this.networkController,
    @required this.requests,
  }) : super(key: key);

  static MethodColumn methodColumn = MethodColumn();
  static UriColumn addressColumn = UriColumn();
  static StatusColumn statusColumn = StatusColumn();
  static TypeColumn typeColumn = TypeColumn();
  static DurationColumn durationColumn = DurationColumn();
  static TimestampColumn timestampColumn = TimestampColumn();

  final NetworkController networkController;
  final List<NetworkRequest> requests;

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
        autoScrollContent: true,
        sortColumn: timestampColumn,
        sortDirection: SortDirection.ascending,
      ),
    );
  }
}

class UriColumn extends ColumnData<NetworkRequest>
    implements ColumnRenderer<NetworkRequest> {
  UriColumn() : super.wide('Uri');

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.uri;
  }

  @override
  Widget build(BuildContext context, NetworkRequest data) {
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

class MethodColumn extends ColumnData<NetworkRequest> {
  MethodColumn() : super('Method', fixedWidthPx: 70);

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.method;
  }
}

class StatusColumn extends ColumnData<NetworkRequest> {
  StatusColumn()
      : super('Status', alignment: ColumnAlignment.right, fixedWidthPx: 62);

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.status;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return dataObject.status == null ? '--' : dataObject.status.toString();
  }
}

class TypeColumn extends ColumnData<NetworkRequest> {
  TypeColumn()
      : super('Type', alignment: ColumnAlignment.right, fixedWidthPx: 62);

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
      : super('Duration', alignment: ColumnAlignment.right, fixedWidthPx: 80);

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
      : super('Timestamp', alignment: ColumnAlignment.right, fixedWidthPx: 135);

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.startTimestamp;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return formatDateTime(dataObject.startTimestamp);
  }
}
