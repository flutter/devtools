// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/code_size/code_size_controller.dart';
import 'package:devtools_app/src/code_size/code_size_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/wrappers.dart';

void main() {
  group('Treemap', () {
    Future<void> pumpCodeSizeBody(
      WidgetTester tester,
      CodeSizeController controller,
    ) async {
      await tester.pumpWidget(wrapWithControllers(
        const CodeSizeBody(),
        codeSize: controller,
      ));
      // Delay to ensure the treemap has been loaded.
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    const windowSize = Size(2225.0, 1000.0);
    testWidgetsWithWindowSize('builds treemap with no data', windowSize,
        (WidgetTester tester) async {
      final controller = CodeSizeController();
      await pumpCodeSizeBody(tester, controller);

      controller.clear();
      await tester.pumpAndSettle();
      
      const treemapKey = Key('Treemap');
      expect(find.byKey(treemapKey), findsNothing);
    });

    testWidgetsWithWindowSize('builds treemap with expected data', windowSize,
        (WidgetTester tester) async {
      final controller = CodeSizeController();
      await pumpCodeSizeBody(tester, controller);

      const treemapKey = Key('Treemap');
      expect(find.byKey(treemapKey), findsOneWidget);

      await expectLater(
        find.byKey(treemapKey),
        matchesGoldenFile('goldens/treemap.png'),
      );
      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgetsWithWindowSize('builds treemap with expected data after zooming in', windowSize,
        (WidgetTester tester) async {
      final controller = CodeSizeController();
      await pumpCodeSizeBody(tester, controller);

      const text = 'package:flutter [1.83 MB]';
      expect(find.text(text), findsOneWidget);
      await tester.tap(find.text(text));

      await tester.pumpAndSettle();

      const treemapKey = Key('Treemap');
      await expectLater(
        find.byKey(treemapKey),
        matchesGoldenFile('goldens/treemap_zoom.png'),
      );
      // Await delay for golden comparison.
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });
}
