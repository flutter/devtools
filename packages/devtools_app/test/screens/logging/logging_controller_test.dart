// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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
import 'package:vm_service/vm_service.dart';

void main() {
  var timestampCounter = 0;

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

    void addStderrData(String message) {
      controller.log(
        LogData(
          'stderr',
          jsonEncode({'kind': 'stderr', 'message': message}),
          ++timestampCounter,
          summary: message,
          level: Level.SEVERE.value,
          isError: true,
        ),
      );
    }

    void addGcData(String message) {
      controller.log(
        LogData(
          'gc',
          jsonEncode({'kind': 'gc', 'message': message}),
          ++timestampCounter,
          summary: message,
          level: Level.INFO.value,
        ),
      );
    }

    void addLog({
      required String kind,
      Level? level,
      String? summary,
      bool isError = false,
      IsolateRef? isolateRef,
      ZoneDescription? zone,
    }) {
      controller.log(
        LogData(
          kind,
          jsonEncode({'foo': 'test_data'}),
          ++timestampCounter,
          summary: summary,
          level: level?.value,
          isError: isError,
          isolateRef: isolateRef,
          zone: zone,
        ),
      );
    }

    void prepareTestLogs() {
      addStdoutData('abc');
      addStdoutData('def');
      addStdoutData('abc ghi');
      addStderrData('This is an abc error');
      addStderrData('This is a def error');
      addLog(kind: 'Flutter.Navigation');
      addLog(kind: 'Flutter.Error', isError: true);
      addLog(
        kind: 'stdout',
        level: Level.FINE,
        zone: (name: '_RootZone', identityHashCode: 123),
      );
      addLog(
        kind: 'stdout',
        level: Level.WARNING,
        zone: (name: '_GhiZone', identityHashCode: 456),
      );
      addLog(
        kind: 'stdout',
        isolateRef: IsolateRef(
          id: 'isolates/123',
          number: '1',
          name: 'abc-isolate',
          isSystemIsolate: false,
        ),
      );

      // The following logs should all be filtered by default.
      addGcData('gc1 abc');
      addGcData('gc2 ghi');
      addLog(kind: 'Flutter.FirstFrame');
      addLog(kind: 'Flutter.FrameworkInitialization');
      addLog(kind: 'Flutter.Frame');
      addLog(kind: 'Flutter.ImageSizesForFrame');
      addLog(kind: 'Flutter.ServiceExtensionStateChanged');
    }

    void disableAllFilters() {
      controller.settingFilters.first.setting.value = Level.ALL.value;
      for (final filter in controller.activeFilter.value.settingFilters.sublist(
        1,
      )) {
        filter.setting.value = false;
      }
    }

    setUp(() {
      setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
      setGlobal(MessageBus, MessageBus());
      setGlobal(PreferencesController, PreferencesController());

      controller = LoggingController()..init();
      // Ensure default filters are applied.
      for (final filter in controller.activeFilter.value.settingFilters) {
        filter.setting.value = filter.defaultValue;
      }
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

    test('matchesForSearch - default filters', () {
      prepareTestLogs();

      expect(controller.filteredData.value, hasLength(10));
      expect(controller.matchesForSearch('abc').length, equals(4));
      expect(controller.matchesForSearch('ghi').length, equals(2));
      expect(controller.matchesForSearch('abcd').length, equals(0));
      expect(controller.matchesForSearch('Flutter*').length, equals(2));
      expect(controller.matchesForSearch('').length, equals(0));

      // Search by event kind.
      expect(controller.matchesForSearch('stdout').length, equals(6));
      expect(controller.matchesForSearch('STDOUT').length, equals(6));
      expect(controller.matchesForSearch('flutter.*').length, equals(2));

      // Search by event level.
      expect(controller.matchesForSearch('warning').length, equals(1));
      expect(controller.matchesForSearch('severe').length, equals(3));

      // Search by isolateRef name.
      expect(controller.matchesForSearch('-isolate').length, equals(1));

      // Search by zone name.
      expect(controller.matchesForSearch('root').length, equals(1));
      expect(controller.matchesForSearch('_ghi').length, equals(1));
      expect(controller.matchesForSearch('zone').length, equals(2));
    });

    test('matchesForSearch - all filters disabled', () {
      disableAllFilters();
      prepareTestLogs();

      expect(controller.filteredData.value, hasLength(17));
      expect(controller.matchesForSearch('abc').length, equals(5));
      expect(controller.matchesForSearch('ghi').length, equals(3));
      expect(controller.matchesForSearch('abcd').length, equals(0));
      expect(controller.matchesForSearch('Flutter*').length, equals(7));
      expect(controller.matchesForSearch('').length, equals(0));

      // Search by event kind.
      expect(controller.matchesForSearch('stdout').length, equals(6));
      expect(controller.matchesForSearch('STDOUT').length, equals(6));
      expect(controller.matchesForSearch('flutter.*').length, equals(7));

      // Search by event level.
      expect(controller.matchesForSearch('warning').length, equals(1));
      expect(controller.matchesForSearch('severe').length, equals(3));

      // Search by isolateRef name.
      expect(controller.matchesForSearch('-isolate').length, equals(1));

      // Search by zone name.
      expect(controller.matchesForSearch('root').length, equals(1));
      expect(controller.matchesForSearch('_ghi').length, equals(1));
      expect(controller.matchesForSearch('zone').length, equals(2));
    });

    test('matchesForSearch sets isSearchMatch property', () {
      prepareTestLogs();

      expect(controller.filteredData.value, hasLength(10));
      controller.search = 'abc';
      var matches = controller.searchMatches.value;
      expect(matches.length, equals(4));
      verifyIsSearchMatch(controller.filteredData.value, matches);

      controller.search = 'Flutter.';
      matches = controller.searchMatches.value;
      expect(matches.length, equals(2));
      verifyIsSearchMatch(controller.filteredData.value, matches);
    });

    test('filterData', () {
      prepareTestLogs();

      // At this point data is filtered by the default setting filter values.
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(10));

      controller.setActiveFilter(query: 'abc');
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter(query: 'def');
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(2));

      controller.setActiveFilter(query: 'abc def');
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(6));

      controller.setActiveFilter(query: 'k:stdout');
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(6));

      controller.setActiveFilter(query: '-k:stdout');
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(4));

      controller.setActiveFilter(query: 'k:stdout abc');
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(3));

      controller.setActiveFilter(query: 'k:stdout,flutter.navigation');
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(7));

      controller.setActiveFilter();
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(10));

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
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(14));

      verboseFlutterServiceFilter.setting.value = false;
      controller.setActiveFilter();
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(15));

      gcFilter.setting.value = false;
      controller.setActiveFilter();
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(17));

      minimumLogLevelFilter.setting.value = Level.SEVERE.value;
      controller.setActiveFilter();
      expect(controller.data, hasLength(17));
      expect(controller.filteredData.value, hasLength(3));
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
        const prettyJson =
            '{\n'
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
