// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
library;

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/primitives/message_bus.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  group('LoggingController', () {
    late LoggingController controller;

    void addStdoutData(String message) {
      controller.log(
        LogData(
          'stdout',
          jsonEncode({'kind': 'stdout', 'message': message}),
          0,
          summary: message,
          level: Level.INFO.value,
        ),
      );
    }

    void addGcData(String message) {
      controller.log(
        LogData(
          'gc',
          jsonEncode({'kind': 'gc', 'message': message}),
          0,
          summary: message,
          level: Level.INFO.value,
        ),
      );
    }

    void addLog({required String kind, Level? level, bool isError = false}) {
      controller.log(
        LogData(
          kind,
          jsonEncode({'foo': 'test_data'}),
          0,
          level: level?.value,
          isError: isError,
        ),
      );
    }

    setUp(() {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceConnectionManager(),
      );
      setGlobal(MessageBus, MessageBus());
      setGlobal(PreferencesController, PreferencesController());

      controller = LoggingController();
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

    test('matchesForSearch', () {
      addStdoutData('abc');
      addStdoutData('def');
      addStdoutData('abc ghi');
      addLog(kind: 'Flutter.Navigation');
      addLog(kind: 'Flutter.Error', isError: true);
      addGcData('gc1');
      addGcData('gc2');

      expect(controller.filteredData.value, hasLength(5));
      expect(controller.matchesForSearch('abc').length, equals(2));
      expect(controller.matchesForSearch('ghi').length, equals(1));
      expect(controller.matchesForSearch('abcd').length, equals(0));
      expect(controller.matchesForSearch('Flutter*').length, equals(2));
      expect(controller.matchesForSearch('').length, equals(0));

      // Search by event kind.
      expect(controller.matchesForSearch('stdout').length, equals(3));
      expect(controller.matchesForSearch('flutter.*').length, equals(2));

      // Search with incorrect case.
      expect(controller.matchesForSearch('STDOUT').length, equals(3));
    });

    test('matchesForSearch sets isSearchMatch property', () {
      addStdoutData('abc');
      addStdoutData('def');
      addStdoutData('abc ghi');
      addLog(kind: 'Flutter.Navigation');
      addLog(kind: 'Flutter.Error', isError: true);
      addGcData('gc1');
      addGcData('gc2');

      expect(controller.filteredData.value, hasLength(5));
      controller.search = 'abc';
      var matches = controller.searchMatches.value;
      expect(matches.length, equals(2));
      verifyIsSearchMatch(controller.filteredData.value, matches);

      controller.search = 'Flutter.';
      matches = controller.searchMatches.value;
      expect(matches.length, equals(2));
      verifyIsSearchMatch(controller.filteredData.value, matches);
    });

    test('filterData', () {
      addStdoutData('abc');
      addStdoutData('def');
      addStdoutData('abc ghi');
      addLog(kind: 'Flutter.Navigation');
      addLog(kind: 'Flutter.Error', isError: true);

      // The following logs should all be filtered by default.
      addGcData('gc1');
      addGcData('gc2');
      addLog(kind: 'Flutter.FirstFrame');
      addLog(kind: 'Flutter.FrameworkInitialization');
      addLog(kind: 'Flutter.Frame');
      addLog(kind: 'Flutter.ImageSizesForFrame');
      addLog(kind: 'Flutter.ServiceExtensionStateChanged');

      // At this point data is filtered by the default toggle filter values.
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(5));

      // Test query filters assuming default setting filters are all enabled.
      controller.activeFilter.value.settingFilters.first.setting.value =
          Level.INFO;
      for (final filter
          in controller.activeFilter.value.settingFilters.sublist(1)) {
        filter.setting.value = true;
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

      // Test setting filters.
      final minimumLogLevelFilter =
          controller.activeFilter.value.settingFilters[0];
      final verboseFlutterFrameworkFilter =
          controller.activeFilter.value.settingFilters[1];
      final verboseFlutterServiceFilter =
          controller.activeFilter.value.settingFilters[2];
      final gcFilter = controller.activeFilter.value.settingFilters[3];

      verboseFlutterFrameworkFilter.setting.value = false;
      controller.setActiveFilter();
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(9));

      verboseFlutterServiceFilter.setting.value = false;
      controller.setActiveFilter();
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(10));

      gcFilter.setting.value = false;
      controller.setActiveFilter();
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(12));

      minimumLogLevelFilter.setting.value = Level.SEVERE;
      controller.setActiveFilter();
      expect(controller.data, hasLength(12));
      expect(controller.filteredData.value, hasLength(1));
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
