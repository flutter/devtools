// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/extent_delegate_list.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExtentDelegateListView', () {
    final children = [1.0, 2.0, 3.0, 4.0];

    Future<void> pumpList(
      WidgetTester tester,
      ExtentDelegateListView listView,
    ) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: listView,
      ));
    }

    testWidgets('builds successfully', (tester) async {
      await pumpList(
        tester,
        ExtentDelegateListView(
          controller: ScrollController(),
          extentDelegate: FixedExtentDelegate(
            computeLength: () => children.length,
            computeExtent: (index) => children[index],
          ),
          childrenDelegate: SliverChildBuilderDelegate(
            (context, index) => Text('${children[index]}'),
            childCount: children.length,
          ),
        ),
      );

      for (final child in children) {
        expect(find.text('$child'), findsOneWidget);
      }
    });

    testWidgets('builds successfully with customPointerSignalHandler',
        (tester) async {
      int pointerSignalEventCount = 0;
      void _handlePointerSignal(PointerSignalEvent event) {
        pointerSignalEventCount++;
      }

      await pumpList(
        tester,
        ExtentDelegateListView(
          controller: ScrollController(),
          extentDelegate: FixedExtentDelegate(
            computeLength: () => children.length,
            computeExtent: (index) => children[index],
          ),
          childrenDelegate: SliverChildBuilderDelegate(
            (context, index) => Text('${children[index]}'),
            childCount: children.length,
          ),
          customPointerSignalHandler: _handlePointerSignal,
        ),
      );

      final scrollEventLocation =
          tester.getCenter(find.byType(ExtentDelegateListView));
      final testPointer = TestPointer(1, PointerDeviceKind.mouse);
      // Create a hover event so that |testPointer| has a location when
      // generating the scroll.
      testPointer.hover(scrollEventLocation);

      await tester.sendEventToBinding(
        testPointer.scroll(const Offset(0.0, 10.0)),
      );
      expect(pointerSignalEventCount, equals(1));
    });

    testWidgets('throws for null childrenDelegate', (tester) async {
      expect(
        () async {
          await pumpList(
            tester,
            ExtentDelegateListView(
              controller: ScrollController(),
              extentDelegate: FixedExtentDelegate(
                computeLength: () => children.length,
                computeExtent: (index) => children[index],
              ),
              childrenDelegate: null,
            ),
          );
        },
        throwsAssertionError,
      );
    });
  });
}
