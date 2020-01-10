// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../http_request_data.dart';

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

  void sort(Function getField, int columnIndex, bool ascending) {
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

    // TODO(bkonyi): is this the number format we want?
    final durationMs = (data.duration == null)
        ? 'In Progress'
        : numFormat.format(data.duration.inMicroseconds / 1000);

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(data.name)),
        DataCell(
          Text(
            data.method,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
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

