// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../ui/flutter/label.dart';
import '../../ui/icons.dart';
import '../http_request_data.dart';
import '../network_controller.dart';
import 'http_request_inspector.dart';

class HttpRequestDataTableSource extends DataTableSource {
  set data(List<HttpRequestData> data) {
    _data = data;
    notifyListeners();
  }

  List<HttpRequestData> _data;

  @override
  int get rowCount => _data?.length ?? 0;

  ValueListenable<HttpRequestData> get currentSelectionListenable =>
      _currentSelection;
  final _currentSelection = ValueNotifier<HttpRequestData>(null);

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;

  void _sort(Function getField, int columnIndex, bool ascending) {
    _data.sort((
      HttpRequestData a,
      HttpRequestData b,
    ) {
      if (!ascending) {
        final tmp = a;
        a = b;
        b = tmp;
      }
      final fieldA = getField(a);
      final fieldB = getField(b);

      // Handle cases where one or both fields are null as Comparable doesn't
      // handle null properly and we still want to allow for sorting.
      if (fieldA == null || fieldB == null) {
        if (fieldA != null) return -1;
        if (fieldB != null) return 1;
        return 0;
      }
      return Comparable.compare(fieldA, fieldB);
    });
    notifyListeners();
  }

  TextStyle _getStatusColor(String status) {
    if (status == null) {
      return const TextStyle();
    }
    final statusInt = int.tryParse(status);
    if (statusInt == null || statusInt >= 400) {
      return const TextStyle(
        color: Colors.redAccent,
      );
    }
    if (statusInt >= 100 && statusInt < 300) {
      return const TextStyle(
        color: Colors.greenAccent,
      );
    }
    if (statusInt >= 300 && statusInt < 400) {
      return const TextStyle(
        color: Colors.yellowAccent,
      );
    }
    return const TextStyle();
  }

  @override
  DataRow getRow(int index) {
    final data = _data[index];
    final numFormat = NumberFormat.decimalPattern();
    final status = (data.status == null) ? '--' : data.status.toString();
    final requestTime = DateFormat.Hms().add_yMd().format(data.requestTime);
    final TextStyle statusColor = _getStatusColor(data.status);

    final durationMs = (data.durationMs == null)
        ? 'In Progress'
        : numFormat.format(data.durationMs);

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(data.name)),
        DataCell(
          Text(
            data.method,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(Text(status, style: statusColor)),
        DataCell(Text(durationMs)),
        DataCell(Text(requestTime)),
      ],
      selected: data.selected,
      onSelectChanged: (bool selected) {
        if (data != _currentSelection.value) {
          _currentSelection.value?.selected = false;
          data.selected = true;
          _currentSelection.value = data;
        } else if (data == _currentSelection.value) {
          _currentSelection.value = null;
          data.selected = false;
        }
        notifyListeners();
      },
    );
  }

  void clearSelection() => _currentSelection.value = null;
}

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
  final networkController = NetworkController();
  final dataTableSource = HttpRequestDataTableSource();

  static bool _sortAscending = false;
  static int _sortColumnIndex;

  static const _headerTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  void _onSort(
    Function getField,
    int columnIndex,
    bool ascending,
  ) {
    dataTableSource._sort(
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
    networkController.initialize();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const double minIncludeTextWidth = 600;
    return ValueListenableBuilder<HttpRequests>(
      valueListenable: networkController.requestsNotifier,
      builder: (context, data, widget) {
        dataTableSource.data = data.requests;
        return ValueListenableBuilder(
          valueListenable: networkController.recordingNotifier,
          builder: (context, recording, widget) {
            return Column(
              children: [
                Row(
                  children: [
                    recordButton(
                      recording: recording,
                      minIncludeTextWidth: minIncludeTextWidth,
                      onPressed: () => networkController.startRecording(),
                    ),
                    pauseButton(
                      paused: !recording,
                      minIncludeTextWidth: minIncludeTextWidth,
                      onPressed: () => networkController.pauseRecording(),
                    ),
                    OutlineButton(
                      onPressed: () => networkController.refreshRequests(),
                      child: Label(
                        FlutterIcons.refresh,
                        'Refresh',
                        minIncludeTextWidth: 900,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    clearButton(
                      onPressed: () {
                        dataTableSource.clearSelection();
                        networkController.clear();
                      },
                    ),
                    const Spacer()
                  ],
                ),
                ValueListenableBuilder(
                  valueListenable: dataTableSource.currentSelectionListenable,
                  builder: (context, HttpRequestData data, widget) {
                    return Expanded(
                      child: (!recording && dataTableSource.rowCount == 0)
                          ? Container(
                              child: Center(
                                child: recordingInfo(
                                  recording: recording,
                                  recordedObject: 'HTTP requests',
                                  isPause: true,
                                ),
                              ),
                            )
                          : Split(
                              initialFirstFraction: 0.5,
                              axis: Axis.horizontal,
                              firstChild: (dataTableSource.rowCount == 0)
                                  ? Container(
                                      alignment: Alignment.center,
                                      child: const CircularProgressIndicator(),
                                    )
                                  : Scrollbar(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          return SingleChildScrollView(
                                            child: PaginatedDataTable(
                                              rowsPerPage: 25,
                                              // TODO(bkonyi): figure out how to prevent header from scrolling.
                                              header: const Text(
                                                'HTTP Requests',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              source: dataTableSource,
                                              includeCheckboxes: false,
                                              columns: [
                                                DataColumn(
                                                  label: Text(
                                                    'Request URI (${dataTableSource.rowCount})',
                                                    style: _headerTextStyle,
                                                  ),
                                                  onSort: (i, j) => _onSort(
                                                    (HttpRequestData o) =>
                                                        o.name,
                                                    i,
                                                    j,
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: const Text(
                                                    'Method',
                                                    style: _headerTextStyle,
                                                  ),
                                                  onSort: (i, j) => _onSort(
                                                    (HttpRequestData o) =>
                                                        o.method,
                                                    i,
                                                    j,
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: const Text(
                                                    'Status',
                                                    style: _headerTextStyle,
                                                  ),
                                                  numeric: true,
                                                  onSort: (i, j) => _onSort(
                                                    (HttpRequestData o) =>
                                                        o.status,
                                                    i,
                                                    j,
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: const Text(
                                                    'Duration (ms)',
                                                    style: _headerTextStyle,
                                                  ),
                                                  numeric: true,
                                                  onSort: (i, j) => _onSort(
                                                    (HttpRequestData o) =>
                                                        o.durationMs,
                                                    i,
                                                    j,
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: const Text(
                                                    'Timestamp',
                                                    style: _headerTextStyle,
                                                  ),
                                                  onSort: (i, j) => _onSort(
                                                    (HttpRequestData o) =>
                                                        o.requestTime,
                                                    i,
                                                    j,
                                                  ),
                                                ),
                                              ],
                                              sortColumnIndex: _sortColumnIndex,
                                              sortAscending: _sortAscending,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                              // Only show the data page when there's data to display.
                              secondChild: HttpRequestInspector(
                                data,
                              ),
                            ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
