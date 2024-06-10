// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
library;

import 'package:devtools_app/src/shared/primitives/custom_pointer_scroll_view.dart';
import 'package:devtools_app/src/shared/primitives/extent_delegate_list.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExtentDelegateListView', () {
    final children = [1.0, 2.0, 3.0, 4.0];

    Future<void> wrapAndPump(
      WidgetTester tester,
      Widget listView,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: listView,
        ),
      );
    }

    testWidgets('builds successfully', (tester) async {
      await wrapAndPump(
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

    testWidgets(
      'builds successfully with customPointerSignalHandler',
      (tester) async {
        int pointerSignalEventCount = 0;
        void handlePointerSignal(PointerSignalEvent _) {
          pointerSignalEventCount++;
        }

        await wrapAndPump(
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
            customPointerSignalHandler: handlePointerSignal,
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
      },
    );

    testWidgets(
      'inherits PrimaryScrollController automatically',
      (tester) async {
        final ScrollController controller = ScrollController();
        await wrapAndPump(
          tester,
          PrimaryScrollController(
            controller: controller,
            child: ExtentDelegateListView(
              extentDelegate: FixedExtentDelegate(
                computeLength: () => children.length,
                computeExtent: (index) => children[index],
              ),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) => Text('${children[index]}'),
                childCount: children.length,
              ),
            ),
          ),
        );

        expect(controller.hasClients, isTrue);
      },
    );

    testWidgets('inherits PrimaryScrollController explicitly', (tester) async {
      final ScrollController controller = ScrollController();
      await wrapAndPump(
        tester,
        PrimaryScrollController(
          controller: controller,
          child: ExtentDelegateListView(
            primary: true,
            extentDelegate: FixedExtentDelegate(
              computeLength: () => children.length,
              computeExtent: (index) => children[index],
            ),
            childrenDelegate: SliverChildBuilderDelegate(
              (context, index) => Text('${children[index]}'),
              childCount: children.length,
            ),
          ),
        ),
      );

      expect(controller.hasClients, isTrue);
    });

    testWidgets(
      'inherits PrimaryScrollController explicitly - horizontal',
      (tester) async {
        final ScrollController controller = ScrollController();
        await wrapAndPump(
          tester,
          PrimaryScrollController(
            controller: controller,
            child: ExtentDelegateListView(
              primary: true,
              scrollDirection: Axis.horizontal,
              extentDelegate: FixedExtentDelegate(
                computeLength: () => children.length,
                computeExtent: (index) => children[index],
              ),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) => Text('${children[index]}'),
                childCount: children.length,
              ),
            ),
          ),
        );

        expect(controller.hasClients, isTrue);
      },
    );

    testWidgets(
      'does not inherit PrimaryScrollController - horizontal',
      (tester) async {
        final ScrollController controller = ScrollController();
        await wrapAndPump(
          tester,
          PrimaryScrollController(
            controller: controller,
            child: ExtentDelegateListView(
              controller: ScrollController(),
              scrollDirection: Axis.horizontal,
              extentDelegate: FixedExtentDelegate(
                computeLength: () => children.length,
                computeExtent: (index) => children[index],
              ),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) => Text('${children[index]}'),
                childCount: children.length,
              ),
            ),
          ),
        );

        expect(controller.hasClients, isFalse);
      },
    );

    testWidgets(
      'does not inherit PrimaryScrollController - explicitly set',
      (tester) async {
        final ScrollController controller = ScrollController();
        await wrapAndPump(
          tester,
          PrimaryScrollController(
            controller: controller,
            child: ExtentDelegateListView(
              primary: false,
              controller: ScrollController(),
              scrollDirection: Axis.horizontal,
              extentDelegate: FixedExtentDelegate(
                computeLength: () => children.length,
                computeExtent: (index) => children[index],
              ),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) => Text('${children[index]}'),
                childCount: children.length,
              ),
            ),
          ),
        );

        expect(controller.hasClients, isFalse);
      },
    );

    testWidgets(
      'does not inherit PrimaryScrollController - other controller set',
      (tester) async {
        final ScrollController primaryController = ScrollController();
        final ScrollController listController = ScrollController();
        await wrapAndPump(
          tester,
          PrimaryScrollController(
            controller: primaryController,
            child: ExtentDelegateListView(
              controller: listController,
              scrollDirection: Axis.horizontal,
              extentDelegate: FixedExtentDelegate(
                computeLength: () => children.length,
                computeExtent: (index) => children[index],
              ),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) => Text('${children[index]}'),
                childCount: children.length,
              ),
            ),
          ),
        );

        expect(primaryController.hasClients, isFalse);
        expect(listController.hasClients, isTrue);
      },
    );

    testWidgets('asserts there is a scroll controller', (tester) async {
      final ScrollController controller = ScrollController();
      await wrapAndPump(
        tester,
        PrimaryScrollController(
          controller: controller,
          child: ExtentDelegateListView(
            scrollDirection: Axis.horizontal,
            extentDelegate: FixedExtentDelegate(
              computeLength: () => children.length,
              computeExtent: (index) => children[index],
            ),
            childrenDelegate: SliverChildBuilderDelegate(
              (context, index) => Text('${children[index]}'),
              childCount: children.length,
            ),
          ),
        ),
      );

      final AssertionError error = tester.takeException() as AssertionError;
      expect(
        error.message,
        'No ScrollController has been provided to the CustomPointerScrollView.',
      );
    });

    testWidgets('implements devicePixelRatio', (tester) async {
      late final BuildContext capturedContext;
      await wrapAndPump(
        tester,
        ExtentDelegateListView(
          controller: ScrollController(),
          extentDelegate: FixedExtentDelegate(
            computeLength: () => children.length,
            computeExtent: (index) => children[index],
          ),
          childrenDelegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == 0) {
                capturedContext = context;
              }
              return Text('${children[index]}');
            },
            childCount: children.length,
          ),
        ),
      );

      expect(
        CustomPointerScrollable.of(capturedContext)!.devicePixelRatio,
        3.0,
      );
    });
  });
}
