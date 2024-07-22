// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/logging/logging_screen_v2/logging_table_row.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const windowSize = Size(1000, 1000);

  setUp(() {
    setGlobal(IdeTheme, getIdeTheme());
    setGlobal(GlobalKey<NavigatorState>, GlobalKey<NavigatorState>());
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
  });

  group('logging_table_row', () {
    for (double windowWidth = 208.0; windowWidth < 600.0; windowWidth += 15.0) {
      const numberOfChips = 3;
      final data = LogDataV2(
        'someKind',
        '{"elapsed": 374}',
        213567823783,
      );
      final windowSize = Size(windowWidth, 500);

      testWidgetsWithWindowSize(
        'Estimates the height of a row correctly for windowWidth: $windowWidth',
        windowSize,
        (WidgetTester tester) async {
          await tester.pumpWidget(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                wrap(
                  LoggingTableRow(
                    index: 0,
                    data: data,
                    isSelected: false,
                  ),
                ),
              ],
            ),
          );
          expect(
            LoggingTableRow.estimateRowHeight(data, windowWidth),
            tester.getSize(find.byType(LoggingTableRow)).height,
          );
        },
      );

      testWidgetsWithWindowSize(
        'Estimates the height of the wrapped chips correctly for windowWidth: $windowWidth',
        windowSize,
        (WidgetTester tester) async {
          final chips = LoggingTableRow.metadataChips(data, windowSize.width);
          final wrapKey = GlobalKey();

          expect(chips.length, numberOfChips);
          await tester.pumpWidget(
            wrap(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    key: wrapKey,
                    children: chips,
                  ),
                ],
              ),
            ),
          );
          expect(
            LoggingTableRow.estimateMetaDataWrapHeight(
              data,
              windowWidth,
            ),
            tester.getSize(find.byKey(wrapKey)).height,
          );
        },
      );
    }

    testWidgetsWithWindowSize(
      'estimates MetadataChip sizes correctly',
      windowSize,
      (WidgetTester tester) async {
        const numberOfChips = 3;
        final data =
            LogDataV2('someKind', '{"elapsed": 378564654}', 213567823783);
        final chips = LoggingTableRow.metadataChips(data, windowSize.width);
        final wrapKey = GlobalKey();

        await tester.pumpWidget(
          wrap(
            Wrap(
              key: wrapKey,
              children: chips,
            ),
          ),
        );

        final chipFinder = find.bySubtype<MetadataChip>();

        expect(chipFinder, findsExactly(numberOfChips));
        final chipElements = chipFinder.evaluate();
        for (var i = 0; i < numberOfChips; i++) {
          final chip = chips[i];
          final chipElement = chipElements.elementAt(i);
          expect(chip.estimateSize(), chipElement.size);
        }
      },
    );
  });
}
