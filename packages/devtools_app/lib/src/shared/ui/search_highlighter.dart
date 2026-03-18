// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../primitives/utils.dart';

/// A utility class for highlighting search matches in text.
extension SearchHighlighter on Never {
  /// Highlights search matches in [text].
  static TextSpan highlight(
    String text,
    List<Range> matches, {
    Range? activeMatch,
    required TextStyle style,
  }) {
    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final spans = <TextSpan>[];
    var lastIndex = 0;
    for (final match in matches) {
      final begin = match.begin.toInt();
      final end = match.end.toInt();
      if (begin > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, begin)));
      }

      final isActive = activeMatch == match;
      spans.add(
        TextSpan(
          text: text.substring(begin, end),
          style: style.copyWith(
            backgroundColor: isActive
                ? activeSearchMatchColor
                : searchMatchColor,
            color: Colors.black,
          ),
        ),
      );
      lastIndex = end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return TextSpan(children: spans, style: style);
  }

  /// Highlights search matches in a list of [TextSpan]s.
  ///
  /// This method handles matches that span across multiple [TextSpan]s.
  static List<InlineSpan> highlightSpans(
    List<TextSpan> spans, {
    required List<Range> matches,
    Range? activeMatch,
    required TextStyle style,
  }) {
    if (matches.isEmpty) return spans;

    final result = <InlineSpan>[];
    var currentOffset = 0;
    var matchIndex = 0;

    for (final span in spans) {
      final spanText = span.toPlainText();
      final spanEnd = currentOffset + spanText.length;

      var lastSpanOffset = 0;

      while (matchIndex < matches.length) {
        final match = matches[matchIndex];

        // Match is after this span.
        if (match.begin >= spanEnd) break;

        // Match ends before this span starts.
        if (match.end <= currentOffset) {
          matchIndex++;
          continue;
        }

        // Add leading un-highlighted text in this span.
        final matchStartInSpan = (match.begin - currentOffset)
            .clamp(0, spanText.length)
            .toInt();
        if (matchStartInSpan > lastSpanOffset) {
          result.add(
            TextSpan(
              text: spanText.substring(lastSpanOffset, matchStartInSpan),
              style: span.style,
            ),
          );
        }

        // Add highlighted portion.
        final matchEndInSpan = (match.end - currentOffset)
            .clamp(0, spanText.length)
            .toInt();
        final isActive = activeMatch == match;
        result.add(
          TextSpan(
            text: spanText.substring(matchStartInSpan, matchEndInSpan),
            style: (span.style ?? style).copyWith(
              backgroundColor: isActive
                  ? activeSearchMatchColor
                  : searchMatchColor,
              color: Colors.black,
            ),
          ),
        );

        lastSpanOffset = matchEndInSpan;

        // If the match continues into the next span, don't increment matchIndex yet.
        if (match.end > spanEnd) break;

        matchIndex++;
      }

      // Add remaining un-highlighted text in this span.
      if (lastSpanOffset < spanText.length) {
        result.add(
          TextSpan(text: spanText.substring(lastSpanOffset), style: span.style),
        );
      }

      currentOffset = spanEnd;
    }

    return result;
  }
}
