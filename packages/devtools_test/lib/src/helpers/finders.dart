// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder findSubstring(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is Text) {
      if (widget.data != null) return widget.data!.contains(text);
      return widget.textSpan!.toPlainText().contains(text);
    } else if (widget is RichText) {
      return widget.text.toPlainText().contains(text);
    } else if (widget is SelectableText) {
      if (widget.data != null) return widget.data!.contains(text);
    }
    return false;
  });
}

extension RichTextChecking on CommonFinders {
  Finder richText(String text) {
    return find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == text,
    );
  }

  Finder richTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
    );
  }
}

extension SelectableTextChecking on CommonFinders {
  Finder selectableText(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText &&
          (widget.data == text || widget.textSpan?.toPlainText() == text),
    );
  }

  Finder selectableTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText &&
          ((widget.data?.contains(text) ?? false) ||
              (widget.textSpan?.toPlainText().contains(text) ?? false)),
    );
  }
}
