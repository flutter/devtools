// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/ui/hover.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

      final overlayContainer = find
          .ancestor(of: hoverContentFinder, matching: find.byType(Container))
          .last; // The outermost container of the HoverCard

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

      final overlayContainer = find
          .ancestor(of: hoverContentFinder, matching: find.byType(Container))
          .last;

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

      final overlayContainer = find
          .ancestor(of: hoverContentFinder, matching: find.byType(Container))
          .last;

      expect(overlayContainer, findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'HoverCard height clamping with title',
    const Size(800, 600),
    (WidgetTester tester) async {
      await pumpHoverCardTooltip(
        tester,
        alignment: Alignment.bottomCenter,
        title: 'An Important Title',
      );

      final hoverContentFinderWithTitle = find.text('Hover Content');
      expect(hoverContentFinderWithTitle, findsOneWidget);

      final containerWithTitle = find
          .ancestor(
            of: hoverContentFinderWithTitle,
            matching: find.byType(Container),
          )
          .last;

      final renderBoxWithTitle =
          tester.renderObject(containerWithTitle) as RenderBox;
      final positionWithTitle = renderBoxWithTitle.localToGlobal(Offset.zero);

      // Clamps strictly at y = 274.0 because of dynamic height containing title/divider.
      expect(positionWithTitle.dy, equals(274.0));
    },
  );

  testWidgetsWithWindowSize(
    'HoverCard height clamping without title',
    const Size(800, 600),
    (WidgetTester tester) async {
      await pumpHoverCardTooltip(tester, alignment: Alignment.bottomCenter);

      final hoverContentFinderNoTitle = find.text('Hover Content');
      expect(hoverContentFinderNoTitle, findsOneWidget);

      final containerNoTitle = find
          .ancestor(
            of: hoverContentFinderNoTitle,
            matching: find.byType(Container),
          )
          .last;

      final renderBoxNoTitle =
          tester.renderObject(containerNoTitle) as RenderBox;
      final positionNoTitle = renderBoxNoTitle.localToGlobal(Offset.zero);

      // Clamps lower down at y = 314.0 because max height is smaller without title gaps.
      expect(positionNoTitle.dy, equals(314.0));
    },
  );

  testWidgetsWithWindowSize(
    'HoverCard translates global coordinates to local coordinates for offset overlays',
    const Size(800, 600),
    (WidgetTester tester) async {
      final overlayKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(left: 50.0, top: 100.0),
              child: Provider<HoverCardController>.value(
                value: HoverCardController(),
                child: Overlay(
                  key: overlayKey,
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => Align(
                        alignment: Alignment.topLeft,
                        child: HoverCardTooltip.sync(
                          enabled: () => true,
                          generateHoverCardData: (event) => HoverCardData(
                            contents: const SizedBox(
                              width: 200,
                              height: 250,
                              child: Text('Hover Content'),
                            ),
                          ),
                          child: const Text('Hover Me Offset'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Trigger hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);

      final center = tester.getCenter(find.text('Hover Me Offset'));
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final hoverContentFinder = find.text('Hover Content');
      expect(hoverContentFinder, findsOneWidget);

      final overlayContainer = find
          .ancestor(of: hoverContentFinder, matching: find.byType(Container))
          .last;

      final renderBox = tester.renderObject(overlayContainer) as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);

      // Dynamic margin is 16.0. Since overlay is offset by 50px globally at the left,
      // dynamic local X is 16.0, mapped to global X = 50.0 + 16.0 = 66.0.
      expect(position.dx, equals(66.0));
    },
  );
}
