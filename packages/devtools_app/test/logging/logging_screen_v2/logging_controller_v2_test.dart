// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: unused_import

@TestOn('vm')
import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/primitives/message_bus.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoggingControllerV2', () {
    late LoggingControllerV2 controller;
    setGlobal(MessageBus, MessageBus());

    void addStdoutData(String message) {
      controller.log(
        LogDataV2(
          'stdout',
          jsonEncode({'kind': 'stdout', 'message': message}),
          0,
          summary: message,
        ),
      );
    }

    void addGcData(String message) {
      controller.log(
        LogDataV2(
          'gc',
          jsonEncode({'kind': 'gc', 'message': message}),
          0,
          summary: message,
        ),
      );
    }

    void addLogWithKind(String kind) {
      controller.log(LogDataV2(kind, jsonEncode({'foo': 'test_data'}), 0));
    }

    setUp(() {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceConnectionManager(),
      );

      controller = LoggingControllerV2();
    });

    test('initial state', () {
      expect(controller.data, isEmpty);
      expect(controller.filteredData.value, isEmpty);
      expect(controller.activeFilter.value.isEmpty, isFalse);
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

    test('filterData', () {
      addStdoutData('abc');
      addStdoutData('def');
      addStdoutData('abc ghi');
      addLogWithKind('Flutter.Navigation');
      addLogWithKind('Flutter.Error');

      // The following logs should all be filtered by default.
      addGcData('gc1');
      addGcData('gc2');
      addLogWithKind('Flutter.FirstFrame');
      addLogWithKind('Flutter.FrameworkInitialization');
      addLogWithKind('Flutter.Frame');
      addLogWithKind('Flutter.ImageSizesForFrame');
      addLogWithKind('Flutter.ServiceExtensionStateChanged');

      // At this point data is filtered by the default toggle filter values.
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(5));

      // Test query filters assuming default toggle filters are all enabled.
      for (final filter in controller.activeFilter.value.toggleFilters) {
        filter.enabled.value = true;
      }

      controller.setActiveFilter(query: 'abc');
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(2));

      controller.setActiveFilter(query: 'def');
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(1));

      controller.setActiveFilter(query: 'abc def');
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(3));

      controller.setActiveFilter(query: 'k:stdout');
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(3));

      controller.setActiveFilter(query: '-k:stdout');
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(2));

      controller.setActiveFilter(query: 'k:stdout abc');
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(2));

      controller.setActiveFilter(query: 'k:stdout,flutter.navigation');
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter();
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(5));

      // Test toggle filters.
      final verboseFlutterFrameworkFilter =
          controller.activeFilter.value.toggleFilters[0];
      final verboseFlutterServiceFilter =
          controller.activeFilter.value.toggleFilters[1];
      final gcFilter = controller.activeFilter.value.toggleFilters[2];

      verboseFlutterFrameworkFilter.enabled.value = false;
      controller.setActiveFilter();
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(9));

      verboseFlutterServiceFilter.enabled.value = false;
      controller.setActiveFilter();
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(10));

      gcFilter.enabled.value = false;
      controller.setActiveFilter();
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(12));
    });
  });

  group('LogData', () {
    test(
      'pretty prints when details are json, and returns its details otherwise.',
      () {
        final nonJson = LogData('some kind', 'Not json', 0);
        final json = LogData(
          'some kind',
          '{"firstValue": "value", "otherValue": "value2"}',
          1,
        );
        final nullDetails = LogData('some kind', null, 1);
        const prettyJson = '{\n'
            '  "firstValue": "value",\n'
            '  "otherValue": "value2"\n'
            '}';

        expect(json.prettyPrinted(), prettyJson);
        expect(nonJson.prettyPrinted(), 'Not json');
        expect(nullDetails.prettyPrinted(), null);
      },
    );
  });
}
