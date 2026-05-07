// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/ui/hover.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late HoverCardController hoverCardController;

  setUp(() {
    hoverCardController = HoverCardController();
  });

  Future<void> pumpHoverCardTooltip(
    WidgetTester tester, {
    required Alignment alignment,
    Size windowSize = const Size(800, 600),
    String? title,
  }) async {
    await tester.binding.setSurfaceSize(windowSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Provider<HoverCardController>.value(
            value: hoverCardController,
            child: Align(
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

  testWidgets('HoverCard at the bottom of the window should not overflow', (WidgetTester tester) async {
    const windowSize = Size(800, 600);
    // Use a title to increase the height beyond the base content height.
    await pumpHoverCardTooltip(
      tester,
      alignment: Alignment.bottomCenter,
      windowSize: windowSize,
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
    expect(position.dy + size.height, lessThanOrEqualTo(windowSize.height - 16.0));
  });

  testWidgets('HoverCard at the right of the window should not overflow', (WidgetTester tester) async {
    const windowSize = Size(800, 600);
    await pumpHoverCardTooltip(tester, alignment: Alignment.centerRight, windowSize: windowSize);

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
    expect(position.dx + size.width, lessThanOrEqualTo(windowSize.width - 16.0));
  });

  testWidgets('HoverCard in very small window should not crash', (WidgetTester tester) async {
    const windowSize = Size(100, 100); // Smaller than tooltip
    await pumpHoverCardTooltip(tester, alignment: Alignment.center, windowSize: windowSize);

    final hoverContentFinder = find.text('Hover Content');
    expect(hoverContentFinder, findsOneWidget);

    final overlayContainer = find.ancestor(
      of: hoverContentFinder,
      matching: find.byType(Container),
    ).last;

    expect(overlayContainer, findsOneWidget);
  });
}
