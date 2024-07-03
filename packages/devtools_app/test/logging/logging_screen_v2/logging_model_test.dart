// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_controller_v2.dart';
import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_model.dart';
import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_table_row.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/preferences/preferences.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoggingModel', () {
    const windowSize = Size(500.0, 500.0);

    late LoggingTableModel loggingTableModel;
    final log1 = LogDataV2('test', 'The details', 464564);

    setUp(() {
      final fakeServiceConnection = FakeServiceConnectionManager();
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(IdeTheme, getIdeTheme());
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(GlobalKey<NavigatorState>, GlobalKey<NavigatorState>());

      TestWidgetsFlutterBinding.ensureInitialized();
      loggingTableModel = LoggingTableModel();
    });

    tearDown(() {
      loggingTableModel.dispose();
    });

    testWidgets('can add logs', (WidgetTester tester) async {
      // A barebones widget is pumped to ensure that a style is available
      // for the LogTableModel to approximate widget sizes with
      await tester.pumpWidget(wrap(const Placeholder()));

      expect(loggingTableModel.logCount, 0);
      expect(loggingTableModel.filteredLogCount, 0);
      expect(loggingTableModel.selectedLogCount, 0);

      loggingTableModel.add(log1);

      expect(loggingTableModel.logCount, 1);
      expect(loggingTableModel.filteredLogCount, 1);
      expect(loggingTableModel.selectedLogCount, 0);
    });

    testWidgetsWithWindowSize('calculate heights correctly', windowSize,
        (WidgetTester tester) async {
      final shortLog = LogDataV2('test', 'Some short details', 464564);
      final longLog = LogDataV2(
        'test',
        'A long log, A long log, A long log, A long log, A long log, A long log, A long log, ',
        464564,
      );

      await tester.pumpWidget(
        wrap(
          Column(
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
            ],
          ),
        ),
      );

      loggingTableModel.add(shortLog);
      loggingTableModel.add(longLog);

      final shortWidgetFinder = find.ancestor(
        of: find.richText(shortLog.details!),
        matching: find.byType(LoggingTableRow),
      );
      final longWidgetFinder = find.ancestor(
        of: find.richText(longLog.details!),
        matching: find.byType(LoggingTableRow),
      );

      await tester.runAsync(() async {
        // tester.runAsync is needed here to prevent the ChunkWorker
        // in set tableWidth from blocking in the test. The Future.delayed
        // in it would hang otherwise.
        loggingTableModel.tableWidth = tester.getSize(shortWidgetFinder).width;
      });

      expect(
        tester.getSize(shortWidgetFinder).height,
        loggingTableModel.getFilteredLogHeight(0),
      );
      expect(
        tester.getSize(longWidgetFinder).height,
        loggingTableModel.getFilteredLogHeight(1),
      );
    });

    testWidgets('Handles log retention', (WidgetTester tester) async {
      final log1 = LogDataV2('test', 'The details 1', 464564);
      final log2 = LogDataV2('test', 'The details 2', 464564);
      final log3 = LogDataV2('test', 'The details 3', 464564);

      // A barebones widget is pumped to ensure that a style is available
      // for the LogTableModel to approximate widget sizes with
      await tester.pumpWidget(wrap(const Placeholder()));

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

      // A barebones widget is pumped to ensure that a style is available
      // for the LogTableModel to approximate widget sizes with
      await tester.pumpWidget(wrap(const Placeholder()));
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

      // A barebones widget is pumped to ensure that a style is available
      // for the LogTableModel to approximate widget sizes with
      await tester.pumpWidget(wrap(const Placeholder()));
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

      // A barebones widget is pumped to ensure that a style is available
      // for the LogTableModel to approximate widget sizes with
      await tester.pumpWidget(wrap(const Placeholder()));
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
}
