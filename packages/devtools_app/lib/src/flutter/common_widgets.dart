// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_widgets/flutter_widgets.dart';

/// Convenience [Divider] with [Padding] to fit in better with forms.
class PaddedDivider extends StatelessWidget {
  const PaddedDivider({
    Key key,
    this.padding = const EdgeInsets.only(bottom: 10.0),
  }) : super(key: key);

  /// The padding to place around the divider.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Divider(thickness: 1.0),
    );
  }
}

/// A [TaggedText] with builtin DevTools-specific text styling.
class DevToolsTaggedText extends StatelessWidget {
  const DevToolsTaggedText(
    this.content, {
    this.textAlign = TextAlign.start,
    Key key,
  }) : super(key: key);

  /// The XML-markupd string to show.
  final String content;

  /// See [TaggedText.textAlign].
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final _tagToTextSpanBuilder = {
      'bold': (text) => TextSpan(
            text: text,
            style: defaultTextStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
      'primary-color': (text) => TextSpan(
            text: text,
            style: defaultTextStyle.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.w400,
            ),
          ),
      'primary-color-light': (text) => TextSpan(
            text: text,
            style: defaultTextStyle.copyWith(
              color: theme.primaryColorLight,
              fontWeight: FontWeight.w300,
            ),
          ),
    };
    return TaggedText(
      content: content,
      tagToTextSpanBuilder: _tagToTextSpanBuilder,
      overflow: TextOverflow.visible,
      maxLines: null,
      textAlign: textAlign,
      style: defaultTextStyle,
    );
  }
}
