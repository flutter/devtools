// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/primitives/utils.dart';
import 'package:devtools_app/src/shared/ui/search_highlighter.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = TextStyle(fontSize: 12.0);

  group('SearchHighlighter.highlight', () {
    test('no matches', () {
      final result = SearchHighlighter.highlight(
        'Hello World',
        [],
        style: style,
      );
      expect(result.text, 'Hello World');
      expect(result.children, isNull);
    });

    test('single match', () {
      final result = SearchHighlighter.highlight('Hello World', [
        const Range(0, 5),
      ], style: style);
      expect(result.children!.length, 2);
      expect(result.children![0].toPlainText(), 'Hello');
      expect(result.children![0].style!.backgroundColor, searchMatchColor);
      expect(result.children![1].toPlainText(), ' World');
    });

    test('multiple matches with active match', () {
      final matches = [const Range(0, 5), const Range(6, 11)];
      final result = SearchHighlighter.highlight(
        'Hello World',
        matches,
        activeMatch: matches[1],
        style: style,
      );
      expect(result.children!.length, 3);
      expect(result.children![0].toPlainText(), 'Hello');
      expect(result.children![0].style!.backgroundColor, searchMatchColor);
      expect(result.children![1].toPlainText(), ' ');
      expect(result.children![2].toPlainText(), 'World');
      expect(
        result.children![2].style!.backgroundColor,
        activeSearchMatchColor,
      );
    });
  });

  group('SearchHighlighter.highlightSpans', () {
    test('no matches', () {
      final spans = [
        const TextSpan(text: 'Hello ', style: style),
        const TextSpan(text: 'World', style: style),
      ];
      final result = SearchHighlighter.highlightSpans(
        spans,
        matches: [],
        style: style,
      );
      expect(result, spans);
    });

    test('match across spans', () {
      final spans = [
        const TextSpan(text: 'Hello ', style: style),
        const TextSpan(text: 'World', style: style),
      ];
      // "o Wor"
      final matches = [const Range(4, 9)];
      final result = SearchHighlighter.highlightSpans(
        spans,
        matches: matches,
        activeMatch: matches[0],
        style: style,
      );

      expect(result.length, 4);
      expect(result[0].toPlainText(), 'Hell');
      expect(result[1].toPlainText(), 'o ');
      expect(result[1].style!.backgroundColor, activeSearchMatchColor);
      expect(result[2].toPlainText(), 'Wor');
      expect(result[2].style!.backgroundColor, activeSearchMatchColor);
      expect(result[3].toPlainText(), 'ld');
    });

    test('multiple matches across multiple spans', () {
      final spans = [
        const TextSpan(text: 'abc', style: style),
        const TextSpan(text: 'def', style: style),
        const TextSpan(text: 'ghi', style: style),
      ];
      // "bcd", "fgh"
      final matches = [const Range(1, 4), const Range(5, 8)];
      final result = SearchHighlighter.highlightSpans(
        spans,
        matches: matches,
        activeMatch: matches[1],
        style: style,
      );

      expect(result.length, 7);
      expect(result[0].toPlainText(), 'a');
      expect(result[1].toPlainText(), 'bc'); // match 1 part 1
      expect(result[1].style!.backgroundColor, searchMatchColor);
      expect(result[2].toPlainText(), 'd'); // match 1 part 2
      expect(result[2].style!.backgroundColor, searchMatchColor);
      expect(result[3].toPlainText(), 'e');
      expect(result[4].toPlainText(), 'f'); // match 2 part 1
      expect(result[4].style!.backgroundColor, activeSearchMatchColor);
      expect(result[5].toPlainText(), 'gh'); // match 2 part 2
      expect(result[5].style!.backgroundColor, activeSearchMatchColor);
      expect(result[6].toPlainText(), 'i');
    });
  });
}
