import 'dart:ui';

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
      const numberOfChits = 3;
      final data = LogDataV2(
        'someKind',
        '{"elapsed": 374}',
        213567823783,
      );
      final windowSize = Size(windowWidth, 500);
      testWidgetsWithWindowSize(
          'Estimates the height of a row correctly for windowWidth: $windowWidth',
          windowSize, (WidgetTester tester) async {
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
      });

      testWidgetsWithWindowSize(
          'Estimates the height of the chits correctly for windowWidth: $windowWidth',
          windowSize, (WidgetTester tester) async {
        final chits = LoggingTableRow.metadataChits(data, windowSize.width);
        final wrapKey = GlobalKey();

        expect(chits.length, numberOfChits);
        await tester.pumpWidget(
          wrap(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  key: wrapKey,
                  children: chits,
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
      });
    }
    testWidgetsWithWindowSize(
        'estimates MetadataChit sizes correctly', windowSize,
        (WidgetTester tester) async {
      const numberOfChits = 3;
      final data =
          LogDataV2('someKind', '{"elapsed": 378564654}', 213567823783);
      final chits = LoggingTableRow.metadataChits(data, windowSize.width);
      final wrapKey = GlobalKey();

      await tester.pumpWidget(
        wrap(
          Wrap(
            key: wrapKey,
            children: chits,
          ),
        ),
      );

      final chitFinder = find.bySubtype<MetadataChit>();

      expect(chitFinder, findsExactly(numberOfChits));
      final chitElements = chitFinder.evaluate();
      for (var i = 0; i < numberOfChits; i++) {
        final chit = chits[i];
        final chitElement = chitElements.elementAt(i);
        expect(chit.getSize(), chitElement.size);
      }
    });
  });
}
