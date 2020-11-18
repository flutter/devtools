// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:convert';

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/inspector_service.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/ui/filter.dart';
import 'package:test/test.dart';

import 'inspector_screen_test.dart';
import 'support/mocks.dart';

void main() {
  group('LoggingController', () {
    LoggingController controller;

    void addStdoutData(String message) {
      controller.log(LogData(
        'stdout',
        jsonEncode({'kind': 'stdout', 'message': message}),
        0,
        summary: message,
      ));
    }

    void addGcData(String message) {
      controller.log(LogData(
        'gc',
        jsonEncode({'kind': 'gc', 'message': message}),
        0,
        summary: message,
      ));
    }

    setUp(() async {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceManager(),
      );

      final InspectorService inspectorService = MockInspectorService();

      controller = LoggingController(inspectorService: inspectorService);
    });

    test('initial state', () {
      expect(controller.data, isEmpty);
      expect(controller.filteredData.value, isEmpty);
      expect(controller.activeFilter.value, isNull);
    });

    test('receives data', () {
      expect(controller.data, isEmpty);

      addStdoutData('Abc.');

      expect(controller.data, isNotEmpty);
      expect(controller.filteredData.value, isNotEmpty);

      expect(controller.data.first.summary, contains('Abc'));
    });

    test('clear', () {
      addStdoutData('Abc.');

      expect(controller.data, isNotEmpty);
      expect(controller.filteredData.value, isNotEmpty);

      controller.clear();

      expect(controller.data, isEmpty);
      expect(controller.filteredData.value, isEmpty);
    });

    test('matchesForSearch', () {
      addStdoutData('abc');
      addStdoutData('def');
      addStdoutData('abc ghi');
      addGcData('gc1');
      addGcData('gc2');

      expect(controller.filteredData.value, hasLength(5));
      expect(controller.matchesForSearch('abc').length, equals(2));
      expect(controller.matchesForSearch('ghi').length, equals(1));
      expect(controller.matchesForSearch('abcd').length, equals(0));
      expect(controller.matchesForSearch('').length, equals(0));

      // Search by event kind.
      expect(controller.matchesForSearch('stdout').length, equals(3));
      expect(controller.matchesForSearch('gc').length, equals(2));

      // Search with incorrect case.
      expect(controller.matchesForSearch('STDOUT').length, equals(3));
    });

    test('filterData', () {
      addStdoutData('abc');
      addStdoutData('def');
      addStdoutData('abc ghi');
      addGcData('gc1');
      addGcData('gc2');

      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(5));

      controller.filterData(QueryFilter.parse('abc', controller.filterArgs));
      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(2));

      controller.filterData(QueryFilter.parse('def', controller.filterArgs));
      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(1));

      controller.filterData(
          QueryFilter.parse('k:stdout abc def', controller.filterArgs));
      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(3));

      controller
          .filterData(QueryFilter.parse('kind:gc', controller.filterArgs));
      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(2));

      controller
          .filterData(QueryFilter.parse('k:stdout abc', controller.filterArgs));
      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(2));

      controller.filterData(QueryFilter.parse('-k:gc', controller.filterArgs));
      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(3));

      controller
          .filterData(QueryFilter.parse('-k:gc,stdout', controller.filterArgs));
      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(0));

      controller.filterData(QueryFilter.parse(
          'k:gc,stdout,stdin,flutter.frame', controller.filterArgs));
      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(5));

      controller.filterData(null);
      expect(controller.data, hasLength(5));
      expect(controller.filteredData.value, hasLength(5));
    });
  });

  group('LogData', () {
    test(
        'pretty prints when details are json, and returns its details otherwise.',
        () {
      final nonJson = LogData('some kind', 'Not json', 0);
      final json = LogData(
          'some kind', '{"firstValue": "value", "otherValue": "value2"}', 1);
      final nullDetails = LogData('some kind', null, 1);
      const prettyJson = '{\n'
          '  "firstValue": "value",\n'
          '  "otherValue": "value2"\n'
          '}';

      expect(json.prettyPrinted, prettyJson);
      expect(nonJson.prettyPrinted, 'Not json');
      expect(nullDetails.prettyPrinted, null);
    });
  });
}
