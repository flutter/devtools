// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

@TestOn('vm')
import 'package:devtools_app/src/shared/primitives/extent_delegate_list.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/utils/extent_delegate_utils.dart';
import '../test_infra/utils/rendering_tester.dart';
import '../test_infra/utils/test_utils.dart';

void main() {
  TestRenderingFlutterBinding.ensureInitialized();
  group('RenderSliverFixedExtentDelgate', () {
    group('extentDelegate', () {
      testWithFlutterTestRegistry('itemExtent', () {
        final extents = [100.0, 200.0, 50.0, 100.0];
        final extentDelegate = FixedExtentDelegate(
          // Create items with increasing extents.
          computeExtent: (index) => extents[index],
          computeLength: () => extents.length,
        );

        expect(extentDelegate.length, equals(4));
        for (int i = 0; i < extents.length; i++) {
          expect(extentDelegate.itemExtent(i), extents[i]);
        }
        expect(extentDelegate.itemExtent(1), 200.0);
        extents[1] = 500.0;
        extentDelegate.recompute();
        expect(extentDelegate.itemExtent(1), 500.0);
      });

      testWithFlutterTestRegistry('getMinChildIndexForScrollOffset', () {
        final extents = [100.0, 200.0, 50.0, 100.0];
        final extentDelegate = FixedExtentDelegate(
          // Create items with increasing extents.
          computeExtent: (index) => extents[index],
          computeLength: () => extents.length,
        );

        expect(extentDelegate.minChildIndexForScrollOffset(0), 0);
        expect(extentDelegate.minChildIndexForScrollOffset(-1000), 0);
        expect(extentDelegate.minChildIndexForScrollOffset(99), 0);
        expect(extentDelegate.minChildIndexForScrollOffset(99.99999999999), 1);
        expect(extentDelegate.minChildIndexForScrollOffset(250), 1);
        expect(extentDelegate.minChildIndexForScrollOffset(299), 1);
        expect(extentDelegate.minChildIndexForScrollOffset(299.99999999999), 2);
        expect(extentDelegate.minChildIndexForScrollOffset(300), 2);
        expect(extentDelegate.minChildIndexForScrollOffset(330), 2);
        expect(extentDelegate.minChildIndexForScrollOffset(350), 3);
        expect(extentDelegate.minChildIndexForScrollOffset(449), 3);
        // Off the end of the list.
        expect(extentDelegate.minChildIndexForScrollOffset(450), 4);
        expect(extentDelegate.minChildIndexForScrollOffset(1000000), 4);
      });

      try {
        testWithFlutterTestRegistry('getMaxChildIndexForScrollOffset', () {
          final extents = [100.0, 200.0, 50.0, 100.0];
          final extentDelegate = FixedExtentDelegate(
            // Create items with increasing extents.
            computeExtent: (index) => extents[index],
            computeLength: () => extents.length,
          );

          expect(extentDelegate.maxChildIndexForScrollOffset(0), 0);
          expect(extentDelegate.maxChildIndexForScrollOffset(-1000), 0);
          expect(extentDelegate.maxChildIndexForScrollOffset(99), 0);
          // The behavior is a bit counter intuitive but this matching the
          // existing fixed extent behavior. The max child for an offset is
          // actually intentionally less than the min child for the case that
          // the child is right on the boundary.
          expect(
            extentDelegate.maxChildIndexForScrollOffset(99.99999999999),
            0,
          );
          expect(extentDelegate.maxChildIndexForScrollOffset(250), 1);
          expect(extentDelegate.maxChildIndexForScrollOffset(299), 1);
          expect(
            extentDelegate.maxChildIndexForScrollOffset(299.99999999999),
            1,
          );
          expect(extentDelegate.maxChildIndexForScrollOffset(300), 1);
          expect(extentDelegate.maxChildIndexForScrollOffset(330), 2);
          expect(extentDelegate.maxChildIndexForScrollOffset(350), 2);
          expect(extentDelegate.maxChildIndexForScrollOffset(449), 3);
          // Off the end of the list.
          expect(extentDelegate.maxChildIndexForScrollOffset(450), 3);
          expect(extentDelegate.maxChildIndexForScrollOffset(1000000), 4);
        });
      } catch (e, s) {
        print(s);
      }

      testWithFlutterTestRegistry('zeroHeightChildren', () {
        // Zero height children could cause problems for the logic to find the
        // min and max matching children.
        final extents = [100.0, 200.0, 0.0, 0.0, 0.0, 100.0];
        final extentDelegate = FixedExtentDelegate(
          // Create items with increasing extents.
          computeExtent: (index) => extents[index],
          computeLength: () => extents.length,
        );

        expect(extentDelegate.minChildIndexForScrollOffset(299), 1);
        expect(extentDelegate.maxChildIndexForScrollOffset(299), 1);
        expect(extentDelegate.minChildIndexForScrollOffset(299.999999999), 1);
        expect(extentDelegate.maxChildIndexForScrollOffset(299.999999999), 1);
        expect(extentDelegate.minChildIndexForScrollOffset(300), 2);
        expect(extentDelegate.maxChildIndexForScrollOffset(300), 1);
        expect(extentDelegate.minChildIndexForScrollOffset(301), 5);
        expect(extentDelegate.maxChildIndexForScrollOffset(301), 5);
      });
    });

    testWithFlutterTestRegistry('layout test - rounding error', () {
      // These heights are ignored as the FixedExtentDelegate determines the
      // size.
      final List<RenderBox> children = <RenderBox>[
        RenderSizedBox(const Size(400.0, 100.0)),
        RenderSizedBox(const Size(400.0, 100.0)),
        RenderSizedBox(const Size(400.0, 100.0)),
      ];

      // Value to tweak to change how large the items are.
      double extentFactor = 800.0;
      final extentDelegate = FixedExtentDelegate(
        // Create items with increasing extents.
        computeExtent: (index) => (index + 1) * extentFactor,
        computeLength: () => children.length,
      );
      final TestRenderSliverBoxChildManager childManager =
          TestRenderSliverBoxChildManager(
        children: children,
        extentDelegate: extentDelegate,
      );
      final RenderViewport root = RenderViewport(
        crossAxisDirection: AxisDirection.right,
        offset: ViewportOffset.zero(),
        cacheExtent: 0,
        children: <RenderSliver>[
          childManager.createRenderSliverExtentDelegate(),
        ],
      );
      layout(root);
      // viewport is 800x600
      // items have height 800, 1600, and 2400.
      expect(children[0].attached, true);
      expect(children[1].attached, false);

      root.offset = ViewportOffset.fixed(800);
      pumpFrame();
      expect(children[0].attached, false);
      expect(children[1].attached, true);
      expect(children[2].attached, false);

      // Simulate double precision error.
      root.offset = ViewportOffset.fixed(2399.999999999998);
      pumpFrame();
      expect(children[0].attached, false);
      expect(children[1].attached, false);
      expect(children[2].attached, true);

      root.offset = ViewportOffset.fixed(800);
      pumpFrame();
      expect(children[0].attached, false);
      expect(children[1].attached, true);
      expect(children[2].attached, false);

      // simulate an animation.
      extentFactor = 1000.0;
      extentDelegate.recompute();
      pumpFrame();
      expect(children[0].attached, true);
      expect(children[1].attached, true);
      expect(children[2].attached, false);
    });
  });
}
