// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/table.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../http/http_request_data.dart';
import '../../utils.dart';
import '../network_controller.dart';
import 'http_request_inspector.dart';
import 'network_model.dart';

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
          valueListenable: networkController.requestsNotifier,
          builder: (context, httpRequests, _) {
            final count = httpRequests.requests.length;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${nf.format(count)} ${pluralize('request', count)}'),
                const SizedBox(width: denseSpacing),
                SizedBox(
                  width: 12,
                  height: 12,
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
  State<StatefulWidget> createState() => NetworkScreenBodyState();
}

class NetworkScreenBodyState extends State<NetworkScreenBody> {
  final _dataTableSource = HttpRequestDataTableSource();

  static bool _sortAscending = false;
  static int _sortColumnIndex;

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

  void _onSort(
    Function getField,
    int columnIndex,
    bool ascending,
  ) {
    _dataTableSource.sort(
      getField,
      ascending,
    );
    setState(() {
      _sortAscending = ascending;
      _sortColumnIndex = columnIndex;
    });
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
          labelOverride: 'Record traffic',
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
            _dataTableSource.clearSelection();
            _networkController.clear();
          },
        ),
      ],
    );
  }

  Widget _buildHttpRequestTable() {
    final titleTheme = Theme.of(context).textTheme.headline6;
    final subheadTheme = Theme.of(context).textTheme.subtitle1;

    DataColumn buildDataColumn(
      String name,
      Function(HttpRequestData) propertyAccessor, {
      bool numeric = false,
    }) {
      return DataColumn(
        label: Text(
          name,
          style: subheadTheme,
        ),
        numeric: numeric,
        onSort: (i, j) => _onSort(propertyAccessor, i, j),
      );
    }

    return SingleChildScrollView(
      // TODO(jacobr): use DevTools specific table.
      child: PaginatedDataTable(
        horizontalMargin: defaultSpacing,
        columnSpacing: defaultSpacing,
        rowsPerPage: 20,
        dataRowHeight: defaultRowHeight,
        // TODO(bkonyi): figure out how to prevent header from scrolling.
        header: Text(
          'HTTP Requests',
          style: titleTheme,
        ),
        source: _dataTableSource,
        showCheckboxColumn: false,
        columns: [
          buildDataColumn(
            'Request Uri',
            (HttpRequestData o) => o.name,
          ),
          buildDataColumn(
            'Method',
            (HttpRequestData o) => o.method,
          ),
          buildDataColumn(
            'Status',
            (HttpRequestData o) => o.status,
            numeric: true,
          ),
          buildDataColumn(
            'Duration (ms)',
            (HttpRequestData o) => o.duration,
            numeric: true,
          ),
          buildDataColumn(
            'Timestamp',
            (HttpRequestData o) => o.requestTime,
          ),
        ],
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
      ),
    );
  }

  Widget _buildHttpProfilerBody(bool isRecording) {
    return ValueListenableBuilder<HttpRequestData>(
      valueListenable: _dataTableSource.currentSelectionListenable,
      builder: (context, HttpRequestData data, widget) {
        return Expanded(
          child: (!isRecording && _dataTableSource.rowCount == 0)
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
                  initialFractions: const [0.6, 0.4],
                  minSizes: const [250, 250],
                  axis: Axis.horizontal,
                  children: [
                    _buildHttpRequestTable(),
                    HttpRequestInspector(data),
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HttpRequests>(
      valueListenable: _networkController.requestsNotifier,
      builder: (context, httpRequestProfile, widget) {
        _dataTableSource.data = httpRequestProfile.requests;
        return ValueListenableBuilder<bool>(
          valueListenable: _networkController.recordingNotifier,
          builder: (context, isRecording, widget) {
            return Column(
              children: [
                _buildHttpProfilerControlRow(isRecording),
                const SizedBox(height: denseRowSpacing),
                _buildHttpProfilerBody(isRecording),
              ],
            );
          },
        );
      },
    );
  }
}
