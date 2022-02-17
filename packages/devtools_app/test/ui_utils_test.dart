// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/service_manager.dart';
import 'package:devtools_app/src/ui/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setGlobal(ServiceConnectionManager, FakeServiceManager());
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
          equals(longest));
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
          equals(longest));
    });
  });

  testWidgetsWithWindowSize('OffsetScrollbar goldens', const Size(300, 300),
      (WidgetTester tester) async {
    const root = Key('root');
    final _scrollControllerX = ScrollController();
    final _scrollControllerY = ScrollController();
    await tester.pumpWidget(
      wrap(
        Scrollbar(
          isAlwaysShown: true,
          key: root,
          controller: _scrollControllerX,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _scrollControllerX,
            child: OffsetScrollbar(
              axis: Axis.vertical,
              isAlwaysShown: true,
              offsetControllerViewportDimension:
                  300, // Matches the extent of the outer ScrollView.
              controller: _scrollControllerY,
              offsetController: _scrollControllerX,
              child: SingleChildScrollView(
                controller: _scrollControllerY,
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
      matchesGoldenFile('goldens/offset_scrollbar_startup.png'),
    );

    _scrollControllerX.jumpTo(500);
    await tester.pumpAndSettle();
    // Screenshot should show horizontal scrollbar scrolled while vertical
    // scrollbar is at its initial offset.
    await expectLater(
      find.byKey(root),
      matchesGoldenFile('goldens/offset_scrollbar_scrolled.png'),
    );
  });
}
