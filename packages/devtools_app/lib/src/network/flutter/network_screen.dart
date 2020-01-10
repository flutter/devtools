// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../http_request_data.dart';
import '../network_controller.dart';
import 'http_request_inspector.dart';
import 'network_model.dart';

class NetworkScreen extends Screen {
  const NetworkScreen() : super();

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Network',
      icon: Icon(Icons.network_check),
    );
  }

  @override
  Widget build(BuildContext context) => const NetworkScreenBody();
}

class NetworkScreenBody extends StatefulWidget {
  const NetworkScreenBody();

  @override
  State<StatefulWidget> createState() => NetworkScreenBodyState();
}

class NetworkScreenBodyState extends State<NetworkScreenBody> {
  final _networkController = NetworkController();
  final _dataTableSource = HttpRequestDataTableSource();

  static bool _sortAscending = false;
  static int _sortColumnIndex;

  void _onSort(
    Function getField,
    int columnIndex,
    bool ascending,
  ) {
    _dataTableSource.sort(
      getField,
      columnIndex,
      ascending,
    );
    setState(() {
      _sortAscending = ascending;
      _sortColumnIndex = columnIndex;
    });
  }

  @override
  void initState() {
    _networkController.initialize();
    super.initState();
  }

  @override
  void dispose() {
    _networkController.dispose();
    super.dispose();
  }

  /// Builds the row of buttons that control the HTTP profiler (e.g., record,
  /// pause, etc.)
  Row _buildHttpProfilerControlRow(bool isRecording) {
    const double minIncludeTextWidth = 600;
    return Row(
      children: [
        recordButton(
          recording: isRecording,
          minIncludeTextWidth: minIncludeTextWidth,
          onPressed: () => _networkController.startRecording(),
        ),
        pauseButton(
          paused: !isRecording,
          minIncludeTextWidth: minIncludeTextWidth,
          onPressed: () => _networkController.pauseRecording(),
        ),
        const SizedBox(width: 8.0),
        clearButton(
          onPressed: () {
            _dataTableSource.clearSelection();
            _networkController.clear();
          },
        ),
      ],
    );
  }

  Widget _buildHttpRequestTable() {
    final titleTheme = Theme.of(context).textTheme.title;
    final subheadTheme = Theme.of(context).textTheme.subhead;

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
        onSort: (i, j) => _onSort(
          propertyAccessor,
          i,
          j,
        ),
      );
    }

    return Scrollbar(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: PaginatedDataTable(
              rowsPerPage: 25,
              // TODO(bkonyi): figure out how to prevent header from scrolling.
              header: Text(
                'HTTP Requests',
                style: titleTheme,
              ),
              source: _dataTableSource,
              showCheckboxColumn: false,
              columns: [
                buildDataColumn(
                  'Request URI (${_dataTableSource.rowCount})',
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
        },
      ),
    );
  }

  Widget _buildHttpProfilerBody(bool isRecording) {
    return ValueListenableBuilder<HttpRequestData>(
      valueListenable: _dataTableSource.currentSelectionListenable,
      builder: (context, HttpRequestData data, widget) {
        return Expanded(
          child: (!isRecording && _dataTableSource.rowCount == 0)
              ? Container(
                  child: Center(
                    child: recordingInfo(
                      recording: isRecording,
                      recordedObject: 'HTTP requests',
                      isPause: true,
                    ),
                  ),
                )
              : Split(
                  initialFirstFraction: 0.5,
                  axis: Axis.horizontal,
                  firstChild: (_dataTableSource.rowCount == 0)
                      ? Container(
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        )
                      : _buildHttpRequestTable(),
                  // Only show the data page when there's data to display.
                  secondChild: HttpRequestInspector(
                    data,
                  ),
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
                _buildHttpProfilerBody(isRecording),
              ],
            );
          },
        );
      },
    );
  }
}
