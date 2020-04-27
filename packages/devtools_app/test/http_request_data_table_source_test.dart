// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/network/flutter/network_model.dart';
import 'package:devtools_app/src/http/http_request_data.dart';
import 'package:devtools_app/src/network/network_controller.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

import 'support/utils.dart';

void main() {
  group('HttpRequestDataTableSource', () {
    HttpRequestDataTableSource dataTable;
    List<HttpRequestData> requests;
    List<HttpRequestData> invalidRequests;

    setUpAll(() async {
      final timeline = await loadNetworkProfileTimeline();
      final httpRequests = NetworkController.processHttpTimelineEventsHelper(
        timeline,
        0,
        currentValues: [],
        invalidRequests: [],
        outstandingRequestsMap: {},
      );
      requests = httpRequests.requests;
      invalidRequests = httpRequests.invalidRequests;
    });

    setUp(() {
      // Reset the data table before each test.
      dataTable = HttpRequestDataTableSource();
    });

    test('check defaults', () {
      expect(dataTable.rowCount, 0);
      expect(dataTable.isRowCountApproximate, false);
      expect(dataTable.currentSelectionListenable.value, isNull);
      expect(dataTable.selectedRowCount, 0);
      expect(requests.length, equals(69));
      // The first request in the json file is intentionally invalid to simulate
      // some network events occurring before the time range json is fetched
      // for.
      expect(invalidRequests.length, equals(1));
    });

    test('time display', () {
      expect(dataTable.formatDuration(null), 'In Progress');
      expect(
        dataTable.formatDuration(const Duration(milliseconds: 1234)),
        '1,234',
      );

      expect(
        dataTable.formatRequestTime(DateTime(2020, 1, 16, 13, 0, 0)),
        '13:00:00 1/16/2020',
      );
    });

    test('verify status colors', () {
      const standard = TextStyle();
      const green = TextStyle(color: Colors.greenAccent);
      const yellow = TextStyle(color: Colors.yellowAccent);
      const red = TextStyle(color: Colors.redAccent);

      // Expect no color for status code < 100.
      expect(dataTable.getStatusColor(null), standard);
      expect(dataTable.getStatusColor('99'), standard);

      // Expect green for status codes [100, 300).
      expect(dataTable.getStatusColor('100'), green);
      expect(dataTable.getStatusColor('299'), green);

      // Expect yellow for status codes [300, 400).
      expect(dataTable.getStatusColor('300'), yellow);
      expect(dataTable.getStatusColor('399'), yellow);

      // Expect red for status codes >= 400 or invalid codes.
      expect(dataTable.getStatusColor('400'), red);
      expect(dataTable.getStatusColor('500'), red);
      expect(dataTable.getStatusColor('9001'), red);
      expect(dataTable.getStatusColor('foobar'), red);
    });

    test('select row', () async {
      expect(dataTable.rowCount, 0);
      dataTable.data = requests;
      expect(dataTable.rowCount, requests.length);

      DataRow row = dataTable.getRow(0);
      expect(row.selected, false);
      expect(dataTable.selectedRowCount, 0);

      // Check selection works properly.
      final selectListener = () {
        row = dataTable.getRow(0);
        expect(row.selected, true);
        expect(dataTable.selectedRowCount, 1);
      };
      await addListenerScope(
        listenable: dataTable,
        listener: selectListener,
        callback: () => row.onSelectChanged(true),
      );

      // Check deselection works properly...
      final deselectListener = () {
        row = dataTable.getRow(0);
        expect(row.selected, false);
        expect(dataTable.selectedRowCount, 0);
      };

      // with clearSelection
      await addListenerScope(
        listenable: dataTable.currentSelectionListenable,
        listener: deselectListener,
        callback: () => dataTable.clearSelection(),
      );

      // and with onSelectChanged(false)
      row.onSelectChanged(true);
      await addListenerScope(
        listenable: dataTable,
        listener: deselectListener,
        callback: () => row.onSelectChanged(false),
      );
    });

    test('verify rows', () {
      expect(dataTable.rowCount, 0);
      dataTable.data = requests;
      expect(dataTable.rowCount, requests.length);

      // Check each row is in the data table and the data cells contain the
      // correct strings.
      for (int i = 0; i < dataTable.rowCount; ++i) {
        final request = requests[i];
        final row = dataTable.getRow(i);
        final cells = row.cells;
        expect(cells.length, 5);

        for (final cell in cells) {
          expect(cell.child, isA<Text>());
        }
        final cellsText = cells.map((cell) => cell.child as Text).toList();
        expect(cellsText[0].data, request.name);
        expect(cellsText[1].data, request.method);
        expect(cellsText[2].data, request.status);
        expect(cellsText[2].style, dataTable.getStatusColor(request.status));
        expect(cellsText[3].data, dataTable.formatDuration(request.duration));
        expect(
          cellsText[4].data,
          dataTable.formatRequestTime(request.requestTime),
        );
      }
    });

    test('sorting', () async {
      expect(dataTable.rowCount, 0);
      dataTable.data = requests;
      expect(dataTable.rowCount, requests.length);

      void verifyOrder(
        Function(HttpRequestData) getField,
        bool ascending,
      ) {
        for (int i = 0; i < dataTable.rowCount - 1; i++) {
          HttpRequestData a = dataTable.data[i];
          HttpRequestData b = dataTable.data[i + 1];
          if (!ascending) {
            final tmp = a;
            a = b;
            b = tmp;
          }
          final fieldA = getField(a);
          final fieldB = getField(b);
          expect(Comparable.compare(fieldA, fieldB), lessThanOrEqualTo(0));
        }
      }

      // Verify sorting both ascending and descending.
      Future<void> verifySorting(
        Function(HttpRequestData) getField,
      ) async {
        bool ascending = true;
        await addListenerScope(
          listenable: dataTable,
          listener: () => verifyOrder(getField, ascending),
          callback: () => dataTable.sort(getField, ascending),
        );

        ascending = false;
        await addListenerScope(
          listenable: dataTable,
          listener: () => verifyOrder(getField, ascending),
          callback: () => dataTable.sort(getField, ascending),
        );
      }

      await verifySorting((data) => data.name);
      await verifySorting((data) => data.method);
      await verifySorting((data) => data.status);
      await verifySorting((data) => data.duration);
      await verifySorting((data) => data.requestTime);
    });
  });
}
