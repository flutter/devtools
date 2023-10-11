// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/ui/utils.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/matchers/matchers.dart';

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(IdeTheme, IdeTheme());
  });

  group('truncateTextSpan', () {
    testWidgets('simple', (WidgetTester tester) async {
      const span = TextSpan(text: 'abcdefghijklmn');
      expect(
        truncateTextSpan(span, 0).toStringDeep(),
        equalsIgnoringHashCodes(
          'TextSpan:\n'
          '  ""\n',
        ),
      );
      expect(
        truncateTextSpan(span, 3).toStringDeep(),
        equalsIgnoringHashCodes(
          'TextSpan:\n'
          '  "abc"\n',
        ),
      );
      expect(
        truncateTextSpan(span, 4000).toStringDeep(),
        equalsIgnoringHashCodes(
          'TextSpan:\n'
          '  "abcdefghijklmn"\n',
        ),
      );
    });

    testWidgets('children', (WidgetTester tester) async {
      const span = TextSpan(
        text: 'parent',
        children: [
          TextSpan(text: 'foo'),
          TextSpan(text: 'bar'),
          TextSpan(text: 'baz'),
        ],
      );
      expect(
        truncateTextSpan(span, 0).toStringDeep(),
        equalsIgnoringHashCodes(
          'TextSpan:\n'
          '  ""\n',
        ),
      );
      expect(
        truncateTextSpan(span, 3).toStringDeep(),
        equalsIgnoringHashCodes(
          'TextSpan:\n'
          '  "par"\n',
        ),
      );
      expect(
        truncateTextSpan(span, 6).toStringDeep(),
        equalsIgnoringHashCodes(
          'TextSpan:\n'
          '  "parent"\n',
        ),
      );
      expect(
        truncateTextSpan(span, 7).toStringDeep(),
        equalsIgnoringHashCodes(
          'TextSpan:\n'
          '  "parent"\n'
          '  TextSpan:\n'
          '    "f"\n',
        ),
      );

      expect(
        truncateTextSpan(span, 4000).toStringDeep(),
        equalsIgnoringHashCodes(
          'TextSpan:\n'
          '  "parent"\n'
          '  TextSpan:\n'
          '    "foo"\n'
          '  TextSpan:\n'
          '    "bar"\n'
          '  TextSpan:\n'
          '    "baz"\n',
        ),
      );
    });

    testWidgets('retainProperties', (WidgetTester tester) async {
      const span = TextSpan(
        text: 'parent',
        style: TextStyle(color: Colors.red),
        children: [
          TextSpan(text: 'foo', style: TextStyle(color: Colors.blue)),
          TextSpan(text: 'bar', style: TextStyle(color: Colors.green)),
          TextSpan(text: 'baz', style: TextStyle(color: Colors.yellow)),
        ],
      );
      expect(
        truncateTextSpan(span, 13).toStringDeep(),
        equalsIgnoringHashCodes(
          'TextSpan:\n'
          '  inherit: true\n'
          '  color: MaterialColor(primary value: Color(0xfff44336))\n'
          '  "parent"\n'
          '  TextSpan:\n'
          '    inherit: true\n'
          '    color: MaterialColor(primary value: Color(0xff2196f3))\n'
          '    "foo"\n'
          '  TextSpan:\n'
          '    inherit: true\n'
          '    color: MaterialColor(primary value: Color(0xff4caf50))\n'
          '    "bar"\n'
          '  TextSpan:\n'
          '    inherit: true\n'
          '    color: MaterialColor(primary value: Color(0xffffeb3b))\n'
          '    "b"\n',
        ),
      );
    });
  });

  group('findLongestTextSpan', () {
    test('returns longest span', () {
      const shortest = TextSpan(text: 'this is a short line of text');
      const longer = TextSpan(text: 'this is a longer line of text');
      const longest = TextSpan(text: 'this is an even longer line of text');

      expect(
        findLongestTextSpan([
          shortest,
          longer,
          longest,
        ]),
        equals(longest),
      );
    });

    test('returns first longest if multiple spans have the same length', () {
      const shortest = TextSpan(text: 'this is a short line of text');
      const longest = TextSpan(text: 'this is a longer line of text');
      const alsoLongest = TextSpan(text: 'this is a ------ line of text');

      expect(
        findLongestTextSpan([
          shortest,
          longest,
          alsoLongest,
        ]),
        equals(longest),
      );
    });
  });

  group('ScreenSize', () {
    testWidgetsWithWindowSize(
      'handles screens with xxs width and xl height',
      const Size(250, 1000),
      (WidgetTester tester) async {
        return expectScreenSize(
          tester,
          width: MediaSize.xxs,
          height: MediaSize.xl,
        );
      },
    );

    testWidgetsWithWindowSize(
      'handles screens with xs width and l height',
      const Size(500, 800),
      (WidgetTester tester) async {
        return expectScreenSize(
          tester,
          width: MediaSize.xs,
          height: MediaSize.l,
        );
      },
    );

    testWidgetsWithWindowSize(
      'handles screens with s width and m height',
      const Size(800, 700),
      (WidgetTester tester) async {
        return expectScreenSize(
          tester,
          width: MediaSize.s,
          height: MediaSize.m,
        );
      },
    );

    testWidgetsWithWindowSize(
      'handles screens with m width and s height',
      const Size(1100, 550),
      (WidgetTester tester) async {
        return expectScreenSize(
          tester,
          width: MediaSize.m,
          height: MediaSize.s,
        );
      },
    );

    testWidgetsWithWindowSize(
      'handles screens with l width and xs height',
      const Size(1400, 400),
      (WidgetTester tester) async {
        return expectScreenSize(
          tester,
          width: MediaSize.l,
          height: MediaSize.xs,
        );
      },
    );

    testWidgetsWithWindowSize(
      'handles screens with xl width and xxs height',
      const Size(1600, 250),
      (WidgetTester tester) async {
        return expectScreenSize(
          tester,
          width: MediaSize.xl,
          height: MediaSize.xxs,
        );
      },
    );
  });

  testWidgetsWithWindowSize(
    'OffsetScrollbar goldens',
    const Size(300, 300),
    (WidgetTester tester) async {
      const root = Key('root');
      final scrollControllerX = ScrollController();
      final scrollControllerY = ScrollController();
      await tester.pumpWidget(
        wrap(
          Scrollbar(
            thumbVisibility: true,
            key: root,
            controller: scrollControllerX,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: scrollControllerX,
              child: OffsetScrollbar(
                axis: Axis.vertical,
                isAlwaysShown: true,
                offsetControllerViewportDimension:
                    300, // Matches the extent of the outer ScrollView.
                controller: scrollControllerY,
                offsetController: scrollControllerX,
                child: SingleChildScrollView(
                  controller: scrollControllerY,
                  child:
                      Container(width: 2000, height: 1000, color: Colors.green),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screenshot should show both vertical and horizontal scrollbars.
      await expectLater(
        find.byKey(root),
        matchesDevToolsGolden(
          '../test_infra/goldens/offset_scrollbar_startup.png',
        ),
      );

      scrollControllerX.jumpTo(500);
      await tester.pumpAndSettle();
      // Screenshot should show horizontal scrollbar scrolled while vertical
      // scrollbar is at its initial offset.
      await expectLater(
        find.byKey(root),
        matchesDevToolsGolden(
          '../test_infra/goldens/offset_scrollbar_scrolled.png',
        ),
      );
    },
  );
}

void expectScreenSize(
  WidgetTester tester, {
  required MediaSize width,
  required MediaSize height,
}) async {
  await tester.pumpWidget(wrap(Container()));
  final BuildContext context = tester.element(find.byType(Container));
  expect(ScreenSize(context).width, equals(width));
  expect(ScreenSize(context).height, equals(height));
}
