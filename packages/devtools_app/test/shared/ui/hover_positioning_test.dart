// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/ui/hover.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHoverCardTooltip(
    WidgetTester tester, {
    required Alignment alignment,
    String? title,
  }) async {
    await tester.pumpWidget(
      wrapSimple(
        Align(
          alignment: alignment,
          child: HoverCardTooltip.sync(
            enabled: () => true,
            generateHoverCardData: (event) => HoverCardData(
              title: title,
              contents: const SizedBox(
                width: 200,
                height: 250,
                child: Text('Hover Content'),
              ),
            ),
            child: const Text('Hover Me'),
          ),
        ),
      ),
    );

    // Trigger hover
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    final center = tester.getCenter(find.text('Hover Me'));
    await gesture.moveTo(center);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgetsWithWindowSize(
    'HoverCard at the bottom of the window should not overflow',
    const Size(800, 600),
    (WidgetTester tester) async {
      // Use a title to increase the height beyond the base content height.
      await pumpHoverCardTooltip(
        tester,
        alignment: Alignment.bottomCenter,
        title: 'A Very Important Title',
      );

      final hoverContentFinder = find.text('Hover Content');
      expect(hoverContentFinder, findsOneWidget);

      final overlayContainer = find.ancestor(
        of: hoverContentFinder,
        matching: find.byType(Container),
      ).last; // The outermost container of the HoverCard

      final renderBox = tester.renderObject(overlayContainer) as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      // _hoverMargin = 16.0
      expect(position.dy + size.height, lessThanOrEqualTo(600.0 - 16.0));
    },
  );

  testWidgetsWithWindowSize(
    'HoverCard at the right of the window should not overflow',
    const Size(800, 600),
    (WidgetTester tester) async {
      await pumpHoverCardTooltip(tester, alignment: Alignment.centerRight);

      final hoverContentFinder = find.text('Hover Content');
      expect(hoverContentFinder, findsOneWidget);

      final overlayContainer = find.ancestor(
        of: hoverContentFinder,
        matching: find.byType(Container),
      ).last;

      final renderBox = tester.renderObject(overlayContainer) as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      // _hoverMargin = 16.0
      expect(position.dx + size.width, lessThanOrEqualTo(800.0 - 16.0));
    },
  );

  testWidgetsWithWindowSize(
    'HoverCard in very small window should not crash',
    const Size(100, 100), // Smaller than tooltip
    (WidgetTester tester) async {
      await pumpHoverCardTooltip(tester, alignment: Alignment.center);

      final hoverContentFinder = find.text('Hover Content');
      expect(hoverContentFinder, findsOneWidget);

      final overlayContainer = find.ancestor(
        of: hoverContentFinder,
        matching: find.byType(Container),
      ).last;

      expect(overlayContainer, findsOneWidget);
    },
  );
}
