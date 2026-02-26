// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/widgets.dart';

/// Converts a [dartDocText] String into a [Text] widget.
class DartDocConverter {
  DartDocConverter(this.dartDocText);

  final String dartDocText;

  /// Converts the [dartDocText] String into a [Text] widget.
  ///
  /// Removes any brackets and backticks and displays the text inside them with
  /// [fixedFontStyle]. All other text uses [regularFontStyle].
  Text toText({
    required TextStyle regularFontStyle,
    required TextStyle fixedFontStyle,
  }) {
    final children = toTextSpans(
      regularFontStyle: regularFontStyle,
      fixedFontStyle: fixedFontStyle,
    );
    return Text.rich(TextSpan(children: children));
  }

  List<TextSpan> toTextSpans({
    required TextStyle regularFontStyle,
    required TextStyle fixedFontStyle,
  }) {
    final text = _removeTemplateIndicators(dartDocText);

    final children = <TextSpan>[];
    int currentIndex = 0;

    while (currentIndex < text.length) {
      final openBracketIndex = text.indexOf('[', currentIndex);
      final openBacktickIndex = text.indexOf('`', currentIndex);

      int nextSpecialCharIndex = -1;
      bool isLink = false;

      if (openBracketIndex != -1 &&
          (openBacktickIndex == -1 || openBracketIndex < openBacktickIndex)) {
        nextSpecialCharIndex = openBracketIndex;
        isLink = true;
      } else if (openBacktickIndex != -1 &&
          (openBracketIndex == -1 || openBacktickIndex < openBracketIndex)) {
        nextSpecialCharIndex = openBacktickIndex;
      }

      if (nextSpecialCharIndex == -1) {
        // No more special characters, add the remaining text.
        children.add(
          TextSpan(text: text.substring(currentIndex), style: regularFontStyle),
        );
        break;
      }

      // Add text before the special character.
      children.add(
        TextSpan(
          text: text.substring(currentIndex, nextSpecialCharIndex),
          style: regularFontStyle,
        ),
      );

      final closeIndex = text.indexOf(
        isLink ? ']' : '`',
        isLink ? nextSpecialCharIndex : nextSpecialCharIndex + 1,
      );
      if (closeIndex == -1) {
        // Treat unmatched brackets/backticks as regular text.
        children.add(
          TextSpan(
            text: text.substring(nextSpecialCharIndex),
            style: regularFontStyle,
          ),
        );
        currentIndex = text.length; // Effectively break the loop.
      } else {
        final content = text.substring(nextSpecialCharIndex + 1, closeIndex);
        children.add(TextSpan(text: content, style: fixedFontStyle));
        currentIndex = closeIndex + 1;
      }
    }
    return children;
  }

  /// Removes @template and @endtemplate indicators from the [input].
  String _removeTemplateIndicators(String input) {
    const templateStart = '{@template';
    const templateEnd = '{@endtemplate';
    const closingCurlyBrace = '}';
    const newLine = '\n';
    String result = '';
    int currentIndex = 0;

    while (currentIndex < input.length) {
      final startTemplateIndex = input.indexOf(templateStart, currentIndex);
      final endTemplateIndex = input.indexOf(templateEnd, currentIndex);

      int templateIndex;
      if (startTemplateIndex != -1 && endTemplateIndex != -1) {
        templateIndex = (startTemplateIndex < endTemplateIndex)
            ? startTemplateIndex
            : endTemplateIndex;
      } else if (startTemplateIndex != -1) {
        templateIndex = startTemplateIndex;
      } else if (endTemplateIndex != -1) {
        templateIndex = endTemplateIndex;
      } else {
        result += input.substring(currentIndex);
        break;
      }

      result += input.substring(currentIndex, templateIndex);

      final closingIndex = input.indexOf(closingCurlyBrace, templateIndex);
      if (closingIndex == -1) {
        result += input.substring(templateIndex);
        break;
      }
      final closingChars =
          input.substring(closingIndex).startsWith('$closingCurlyBrace$newLine')
          ? '$closingCurlyBrace$newLine'
          : closingCurlyBrace;
      currentIndex = closingIndex + closingChars.length;
    }

    return result;
  }
}
