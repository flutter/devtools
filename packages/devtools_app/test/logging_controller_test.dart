// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:convert';

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/inspector_service.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:test/test.dart';

import 'flutter/inspector_screen_test.dart';
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

    setUp(() async {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceManager(useFakeService: true),
      );

      final InspectorService inspectorService = MockInspectorService();

      controller = LoggingController(inspectorService: inspectorService);
    });

    test('initial state', () {
      expect(controller.data, isEmpty);
      expect(controller.filteredData, isEmpty);
      expect(controller.filterText, isNull);
    });

    test('receives data', () {
      expect(controller.data, isEmpty);

      addStdoutData('Abc.');

      expect(controller.data, isNotEmpty);
      expect(controller.filteredData, isNotEmpty);

      expect(controller.data.first.summary, contains('Abc'));
    });

    test('clear', () {
      addStdoutData('Abc.');

      expect(controller.data, isNotEmpty);
      expect(controller.filteredData, isNotEmpty);

      controller.clear();

      expect(controller.data, isEmpty);
      expect(controller.filteredData, isEmpty);
    });

    test('filteredData', () {
      addStdoutData('abc');
      addStdoutData('def');
      addStdoutData('abc ghi');

      expect(controller.data, hasLength(3));
      expect(controller.filteredData, hasLength(3));

      controller.filterText = 'abc';

      expect(controller.data, hasLength(3));
      expect(controller.filteredData, hasLength(2));

      controller.filterText = 'def';

      expect(controller.data, hasLength(3));
      expect(controller.filteredData, hasLength(1));

      controller.filterText = null;

      expect(controller.data, hasLength(3));
      expect(controller.filteredData, hasLength(3));
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
