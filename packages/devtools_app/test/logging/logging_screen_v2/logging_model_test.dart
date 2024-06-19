// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_table_row.dart';
import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_table_v2.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoggingModel', () {
    const windowSize = Size(500.0, 500.0);

    late LoggingTableModel loggingTableModel;
    final log1 = LogDataV2('test', 'The details', 464564);

    setUp(() {
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(IdeTheme, getIdeTheme());
      setGlobal(GlobalKey<NavigatorState>, GlobalKey<NavigatorState>());
      TestWidgetsFlutterBinding.ensureInitialized();
      loggingTableModel = LoggingTableModel();
    });

    tearDown(() async {
      loggingTableModel.dispose();
    });

    group('logs', () {
      testWidgets('can add logs', (WidgetTester tester) async {
        // A barebones widget is pumped to ensure that a style is available
        // for the LogTableModel to approximate widget sizes with
        await tester.pumpWidget(wrap(const Text('')));

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
          loggingTableModel.tableWidth =
              tester.getSize(shortWidgetFinder).width;
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
        await tester.pumpWidget(wrap(const Text('')));

        preferences.logging.retentionLimit.value = 2;
        await tester.pump();

        loggingTableModel.add(log1);
        loggingTableModel.add(log2);
        loggingTableModel.add(log3);

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
    });
  });
}
