// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_controller_v2.dart';
import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_model.dart';
import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_table_row.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/preferences/preferences.dart';
import 'package:devtools_app/src/shared/primitives/message_bus.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LoggingTableModel loggingTableModel;
  final log1 = LogDataV2('test', 'The details', 464564);

  Future<void> pumpForContext(WidgetTester tester) async {
    // A barebones widget is pumped to ensure that a style is available
    // for the LogTableModel to approximate widget sizes with
    await tester.pumpWidget(wrap(const Placeholder()));
  }

  Finder findLogRow(String details) => find.ancestor(
        of: find.richText(details),
        matching: find.byType(LoggingTableRow),
      );

  setUp(() {
    final fakeServiceConnection = FakeServiceConnectionManager();
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(IdeTheme, getIdeTheme());
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(GlobalKey<NavigatorState>, GlobalKey<NavigatorState>());

    TestWidgetsFlutterBinding.ensureInitialized();
    loggingTableModel = LoggingTableModel();

    // Set a generic width for all tests
    loggingTableModel.tableWidth = 500;
  });

  tearDown(() {
    loggingTableModel.dispose();
  });

  group('LoggingModel', () {
    testWidgets('can add logs', (WidgetTester tester) async {
      await pumpForContext(tester);
      expect(loggingTableModel.logCount, 0);
      expect(loggingTableModel.filteredLogCount, 0);
      expect(loggingTableModel.selectedLogCount, 0);

      loggingTableModel.add(log1);

      expect(loggingTableModel.logCount, 1);
      expect(loggingTableModel.filteredLogCount, 1);
      expect(loggingTableModel.selectedLogCount, 0);
    });

    for (var windowWidth = 300.0; windowWidth <= 550.0; windowWidth += 50.0) {
      testWidgetsWithWindowSize(
        'calculate heights correctly for window of width: $windowWidth',
        Size(windowWidth, 3000),
        (WidgetTester tester) async {
          await pumpForContext(tester);
          final shortLog = LogDataV2('test', 'Some short details', 464564);
          final longLog = LogDataV2(
            'test',
            'A long log, A long log, A long log, A long log, A long log, A long log, A long log, ',
            464564,
          );
          final frameElapsedLog =
              LogDataV2('frameLog', '{"elapsed": 1000000}', 4684506);
          double? columnWidth;
          final frameElapsedKey = GlobalKey();

          await tester.pumpWidget(
            wrap(
              LayoutBuilder(
                builder: (context, constraints) {
                  columnWidth = constraints.maxWidth;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LoggingTableRow(
                        index: 0,
                        data: shortLog,
                        isSelected: false,
                      ),
                      LoggingTableRow(
                        index: 1,
                        data: longLog,
                        isSelected: false,
                      ),
                      LoggingTableRow(
                        key: frameElapsedKey,
                        index: 2,
                        data: frameElapsedLog,
                        isSelected: false,
                      ),
                    ],
                  );
                },
              ),
            ),
          );

          await tester.runAsync(() async {
            // tester.runAsync is needed here to prevent the ChunkWorker
            // in set tableWidth from blocking in the test. The Future.delayed
            // in it would hang otherwise.
            loggingTableModel.tableWidth = columnWidth!;
          });

          loggingTableModel
            ..add(shortLog)
            ..add(longLog)
            ..add(frameElapsedLog);

          final shortWidgetFinder = findLogRow(shortLog.details!);
          final longWidgetFinder = findLogRow(longLog.details!);
          final frameElapsedFinder = find.byKey(frameElapsedKey);

          await tester.runAsync(() async {
            // tester.runAsync is needed here to prevent the ChunkWorker
            // in set tableWidth from blocking in the test. The Future.delayed
            // in it would hang otherwise.
            loggingTableModel.tableWidth = windowWidth;
          });

          expect(
            loggingTableModel.getFilteredLogHeight(0),
            tester.getSize(shortWidgetFinder).height,
          );
          expect(
            loggingTableModel.getFilteredLogHeight(1),
            tester.getSize(longWidgetFinder).height,
          );
          expect(
            loggingTableModel.getFilteredLogHeight(2),
            tester.getSize(frameElapsedFinder).height,
          );
        },
      );
    }

    testWidgets('Handles log retention', (WidgetTester tester) async {
      final log1 = LogDataV2('test', 'The details 1', 464564);
      final log2 = LogDataV2('test', 'The details 2', 464564);
      final log3 = LogDataV2('test', 'The details 3', 464564);

      await pumpForContext(tester);

      preferences.logging.retentionLimit.value = 2;
      await tester.pump();

      loggingTableModel
        ..add(log1)
        ..add(log2)
        ..add(log3);

      expect(loggingTableModel.logCount, 2);
      expect(loggingTableModel.filteredLogCount, 2);
      expect(loggingTableModel.selectedLogCount, 0);

      final completer = Completer<void>();
      loggingTableModel.addListener(() => completer.complete());
      preferences.logging.retentionLimit.value = 1;
      await completer.future;

      expect(loggingTableModel.logCount, 1);
      expect(loggingTableModel.filteredLogCount, 1);
      expect(loggingTableModel.selectedLogCount, 0);
    });

    testWidgets('filters logs', (WidgetTester tester) async {
      final log1 = LogDataV2('test', 'The details 123', 464564);
      final log2 = LogDataV2('test', 'The details 456', 464564);
      final log3 = LogDataV2('test', 'The details 476', 464564);

      await pumpForContext(tester);

      preferences.logging.retentionLimit.value = 20;

      loggingTableModel
        ..add(log1)
        ..add(log2)
        ..add(log3);

      expect(loggingTableModel.logCount, 3);
      expect(loggingTableModel.filteredLogCount, 3);
      expect(loggingTableModel.selectedLogCount, 0);

      // Set the filter
      loggingTableModel.setActiveFilter(
        query: '6',
      );

      expect(loggingTableModel.logCount, 3);
      expect(loggingTableModel.filteredLogCount, 2);
      expect(loggingTableModel.selectedLogCount, 0);

      // Add a log that does not match to ensure it is filtered out
      loggingTableModel
          .add(LogDataV2('test', 'some non-matching details', 45654));

      expect(loggingTableModel.logCount, 4);
      expect(loggingTableModel.filteredLogCount, 2);
      expect(loggingTableModel.selectedLogCount, 0);

      // Add a log that matches to ensure that it is included
      loggingTableModel
          .add(LogDataV2('test', 'some matching details: 6', 45654));

      expect(loggingTableModel.logCount, 5);
      expect(loggingTableModel.filteredLogCount, 3);
      expect(loggingTableModel.selectedLogCount, 0);
    });

    testWidgets('filters by all relevant fields', (WidgetTester tester) async {
      final log1 = LogDataV2(
        'test1',
        'The details 4',
        464564,
        summary: 'Summary 7',
      );
      final log2 = LogDataV2(
        'test2',
        'The details 5',
        464564,
        summary: 'Summary 8',
      );
      final log3 = LogDataV2(
        'test3',
        'The details 6',
        464564,
        summary: 'Summary 9',
      );

      await pumpForContext(tester);

      preferences.logging.retentionLimit.value = 20;

      loggingTableModel
        ..add(log1)
        ..add(log2)
        ..add(log3);

      expect(loggingTableModel.logCount, 3);
      expect(loggingTableModel.filteredLogCount, 3);
      expect(loggingTableModel.selectedLogCount, 0);

      // Check against kind
      loggingTableModel.setActiveFilter(
        query: '1',
      );

      expect(loggingTableModel.logCount, 3);
      expect(loggingTableModel.filteredLogCount, 1);
      expect(loggingTableModel.selectedLogCount, 0);
      expect(loggingTableModel.filteredLogAt(0), equals(log1));

      // Check against details
      loggingTableModel.setActiveFilter(
        query: '5',
      );

      expect(loggingTableModel.logCount, 3);
      expect(loggingTableModel.filteredLogCount, 1);
      expect(loggingTableModel.selectedLogCount, 0);
      expect(loggingTableModel.filteredLogAt(0), equals(log2));

      // Check against summary
      loggingTableModel.setActiveFilter(
        query: '9',
      );

      expect(loggingTableModel.logCount, 3);
      expect(loggingTableModel.filteredLogCount, 1);
      expect(loggingTableModel.selectedLogCount, 0);
      expect(loggingTableModel.filteredLogAt(0), equals(log3));
    });

    testWidgets('works with regexp', (WidgetTester tester) async {
      final log1 = LogDataV2(
        'test1',
        '456',
        464564,
        summary: 'Summary 7',
      );
      final log2 = LogDataV2(
        'test2',
        '789',
        464564,
        summary: 'Summary 8',
      );
      final log3 = LogDataV2(
        'test3',
        '476',
        464564,
        summary: 'Summary 9',
      );

      await pumpForContext(tester);

      preferences.logging.retentionLimit.value = 20;

      loggingTableModel
        ..add(log1)
        ..add(log2)
        ..add(log3);

      expect(loggingTableModel.logCount, 3);
      expect(loggingTableModel.filteredLogCount, 3);
      expect(loggingTableModel.selectedLogCount, 0);

      loggingTableModel.setActiveFilter(
        query: '4.6',
      );

      expect(loggingTableModel.logCount, 3);
      expect(loggingTableModel.filteredLogCount, 0);
      expect(loggingTableModel.selectedLogCount, 0);

      loggingTableModel.useRegExp.value = true;
      loggingTableModel.setActiveFilter(
        query: '4.6',
      );

      expect(loggingTableModel.logCount, 3);
      expect(loggingTableModel.filteredLogCount, 2);
      expect(loggingTableModel.selectedLogCount, 0);
      expect(loggingTableModel.filteredLogAt(0), equals(log1));
      expect(loggingTableModel.filteredLogAt(1), equals(log3));
    });
  });

  group('Original LoggingController tests', () {
    setGlobal(MessageBus, MessageBus());

    void addStdoutData(String message) {
      loggingTableModel.add(
        LogDataV2(
          'stdout',
          jsonEncode({'kind': 'stdout', 'message': message}),
          0,
          summary: message,
        ),
      );
    }

    void addGcData(String message) {
      loggingTableModel.add(
        LogDataV2(
          'gc',
          jsonEncode({'kind': 'gc', 'message': message}),
          0,
          summary: message,
        ),
      );
    }

    void addLogWithKind(String kind) {
      loggingTableModel
          .add(LogDataV2(kind, jsonEncode({'foo': 'test_data'}), 0));
    }

    setUp(() {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceConnectionManager(),
      );
    });

    test('initial state', () {
      expect(loggingTableModel.logCount, 0);
      expect(loggingTableModel.filteredLogCount, 0);
      expect(loggingTableModel.activeFilter.value.isEmpty, isFalse);
    });

    testWidgets('receives data', (WidgetTester tester) async {
      await pumpForContext(tester);

      expect(loggingTableModel.logCount, 0);

      addStdoutData('Abc.');

      expect(loggingTableModel.logCount, greaterThan(0));
      expect(loggingTableModel.filteredLogCount, greaterThan(0));

      expect(loggingTableModel.filteredLogAt(0).summary, contains('Abc'));
    });

    testWidgets('clear', (WidgetTester tester) async {
      await pumpForContext(tester);
      addStdoutData('Abc.');

      expect(loggingTableModel.logCount, greaterThan(0));
      expect(loggingTableModel.filteredLogCount, greaterThan(0));

      loggingTableModel.clear();

      expect(loggingTableModel.logCount, 0);
      expect(loggingTableModel.filteredLogCount, 0);
    });

    // test('matchesForSearch', () {
    //   addStdoutData('abc');
    //   addStdoutData('def');
    //   addStdoutData('abc ghi');
    //   addLogWithKind('Flutter.Navigation');
    //   addLogWithKind('Flutter.Error');
    //   addGcData('gc1');
    //   addGcData('gc2');
    //
    //   expect(loggingTableModel.filteredData.value, 5);
    //   expect(loggingTableModel.matchesForSearch('abc').length, equals(2));
    //   expect(loggingTableModel.matchesForSearch('ghi').length, equals(1));
    //   expect(loggingTableModel.matchesForSearch('abcd').length, equals(0));
    //   expect(loggingTableModel.matchesForSearch('Flutter*').length, equals(2));
    //   expect(loggingTableModel.matchesForSearch('').length, equals(0));
    //
    //   // Search by event kind.
    //   expect(loggingTableModel.matchesForSearch('stdout').length, equals(3));
    //   expect(loggingTableModel.matchesForSearch('flutter.*').length, equals(2));
    //
    //   // Search with incorrect case.
    //   expect(loggingTableModel.matchesForSearch('STDOUT').length, equals(3));
    // });
    //
    // test('matchesForSearch sets isSearchMatch property', () {
    //   addStdoutData('abc');
    //   addStdoutData('def');
    //   addStdoutData('abc ghi');
    //   addLogWithKind('Flutter.Navigation');
    //   addLogWithKind('Flutter.Error');
    //   addGcData('gc1');
    //   addGcData('gc2');
    //
    //   expect(loggingTableModel.filteredData.value, 5);
    //   loggingTableModel.search = 'abc';
    //   var matches = loggingTableModel.searchMatches.value;
    //   expect(matches.length, equals(2));
    //   verifyIsSearchMatch(loggingTableModel.filteredData.value, matches);
    //
    //   loggingTableModel.search = 'Flutter.';
    //   matches = loggingTableModel.searchMatches.value;
    //   expect(matches.length, equals(2));
    //   verifyIsSearchMatch(loggingTableModel.filteredData.value, matches);
    // });

    testWidgets('filterData', (WidgetTester tester) async {
      await pumpForContext(tester);

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
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 5);

      // Test query filters assuming default toggle filters are all enabled.
      for (final filter in loggingTableModel.activeFilter.value.toggleFilters) {
        filter.enabled.value = true;
      }

      loggingTableModel.setActiveFilter(query: 'abc');
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 2);

      loggingTableModel.setActiveFilter(query: 'def');
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 1);

      loggingTableModel.setActiveFilter(query: 'abc def');
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 3);

      loggingTableModel.setActiveFilter(query: 'k:stdout');
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 3);

      loggingTableModel.setActiveFilter(query: '-k:stdout');
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 2);

      loggingTableModel.setActiveFilter(query: 'k:stdout abc');
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 2);

      loggingTableModel.setActiveFilter(query: 'k:stdout,flutter.navigation');
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 4);

      loggingTableModel.setActiveFilter();
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 5);

      // Test toggle filters.
      final verboseFlutterFrameworkFilter =
          loggingTableModel.activeFilter.value.toggleFilters[0];
      final verboseFlutterServiceFilter =
          loggingTableModel.activeFilter.value.toggleFilters[1];
      final gcFilter = loggingTableModel.activeFilter.value.toggleFilters[2];

      verboseFlutterFrameworkFilter.enabled.value = false;
      loggingTableModel.setActiveFilter();
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 9);

      verboseFlutterServiceFilter.enabled.value = false;
      loggingTableModel.setActiveFilter();
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 10);

      gcFilter.enabled.value = false;
      loggingTableModel.setActiveFilter();
      expect(loggingTableModel.logCount, 12);
      expect(loggingTableModel.filteredLogCount, 12);
    });
  });
}
