// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/widgets.dart';
import '_utils_desktop.dart' if (dart.library.js_interop) '_utils_web.dart';

/// Converts a [dartDocText] String into a [RichText] widget.
///
/// Removes any brackets and backticks and displays the text inside them as
/// fixed font.
RichText convertDartDocToRichText(
  String dartDocText, {
  required TextStyle regularFontStyle,
  required TextStyle fixedFontStyle,
}) {
  final children = <TextSpan>[];
  int currentIndex = 0;

  while (currentIndex < dartDocText.length) {
    final openBracketIndex = dartDocText.indexOf('[', currentIndex);
    final openBacktickIndex = dartDocText.indexOf('`', currentIndex);

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
        TextSpan(
          text: dartDocText.substring(currentIndex),
          style: regularFontStyle,
        ),
      );
      break;
    }

    // Add text before the special character.
    children.add(
      TextSpan(
        text: dartDocText.substring(currentIndex, nextSpecialCharIndex),
        style: regularFontStyle,
      ),
    );

    final closeIndex = dartDocText.indexOf(
      isLink ? ']' : '`',
      isLink ? nextSpecialCharIndex : nextSpecialCharIndex + 1,
    );
    if (closeIndex == -1) {
      // Treat unmatched brackets/backticks as regular text.
      children.add(
        TextSpan(
          text: dartDocText.substring(nextSpecialCharIndex),
          style: regularFontStyle,
        ),
      );
      currentIndex = dartDocText.length; // Effectively break the loop.
    } else {
      final content = dartDocText.substring(
        nextSpecialCharIndex + 1,
        closeIndex,
      );
      children.add(TextSpan(text: content, style: fixedFontStyle));
      currentIndex = closeIndex + 1;
    }
  }

  return RichText(text: TextSpan(children: children));
}

/// Workaround to prevent TextFields from holding onto focus when IFRAME-ed.
///
/// See https://github.com/flutter/devtools/issues/8929 for details.
void setUpTextFieldFocusFixHandler() {
  addBlurListener();
}

/// Workaround to prevent TextFields from holding onto focus when IFRAME-ed.
///
/// See https://github.com/flutter/devtools/issues/8929 for details.
void removeTextFieldFocusFixHandler() {
  removeBlurListener();
}
