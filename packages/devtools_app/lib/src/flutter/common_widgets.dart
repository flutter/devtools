// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_widgets/flutter_widgets.dart';

import '../framework/framework_core.dart';

const tooltipWait = Duration(milliseconds: 500);

/// Convenience [Divider] with [Padding] that provides a good divider in forms.
class PaddedDivider extends StatelessWidget {
  const PaddedDivider({
    Key key,
    this.padding = const EdgeInsets.only(bottom: 10.0),
  }) : super(key: key);

  const PaddedDivider.thin({Key key})
      : padding = const EdgeInsets.only(bottom: 4.0);

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
///
/// This widget is a wrapper around Flutter's [RichText]. It's an alternative
/// to that for richly-formatted text. The performance is roughly the same,
/// and it will throw assertion errors in any cases where the text isn't
/// parsed properly.
///
/// The xml styling is much easier to read than creating multiple [TextSpan]s
/// in a [RichText].  For example, the following are equivalent text
/// presentations:
///
/// ```dart
/// var taggedText = DefaultTaggedText(
///   '<bold>bold text</bold>\n'
///   'normal text',
/// );
///
/// var richText = RichText(
///   style
///   text: TextSpan(
///     text: '',
///     style: DefaultTextStyle.of(context)
///     children: [
///       TextSpan(
///         text: 'bold text',
///         style: DefaultTextStyle.of(context).copyWith(fontWeight: FontWeight.w600),
///       ),
///       TextSpan(
///         text: '\nnormal text',
///       )
///     ],
///   ),
/// );
/// ```
///
/// The [TaggedText] abstraction separates the styling from the content
/// of the rich strings we show in the UI.
///
/// The [TaggedText] also has the benefit of being localizable by a
/// human translator. The content is passed in to Flutter as a single
/// string, and the xml markup is understood by many translators.
class DefaultTaggedText extends StatelessWidget {
  const DefaultTaggedText(
    this.content, {
    this.textAlign = TextAlign.start,
    Key key,
  }) : super(key: key);

  /// The XML-markup string to show.
  final String content;

  /// See [TaggedText.textAlign].
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final _tagToTextSpanBuilder = {
      'bold': (text) => TextSpan(
            text: text,
            style: semibold(defaultTextStyle),
          ),
      'primary-color': (text) =>
          TextSpan(text: text, style: primaryColor(defaultTextStyle, context)),
      'primary-color-light': (text) => TextSpan(
          text: text, style: primaryColorLight(defaultTextStyle, context)),
    };
    return TaggedText(
      content: content,
      tagToTextSpanBuilder: _tagToTextSpanBuilder,
      overflow: TextOverflow.visible,
      textAlign: textAlign,
      style: defaultTextStyle,
    );
  }
}

/// Creates a semibold version of [style].
TextStyle semibold(TextStyle style) =>
    style.copyWith(fontWeight: FontWeight.w600);

/// Creates a version of [style] that uses the primary color of [context].
///
/// When the app is in dark mode, it instead uses the accent color.
TextStyle primaryColor(TextStyle style, BuildContext context) {
  final theme = Theme.of(context);
  return style.copyWith(
    color: (theme.brightness == Brightness.light)
        ? theme.primaryColor
        : theme.accentColor,
    fontWeight: FontWeight.w400,
  );
}

/// Creates a version of [style] that uses the lighter primary color of
/// [context].
///
/// In dark mode, the light primary color still has enough contrast to be
/// visible, so we continue to use it.
TextStyle primaryColorLight(TextStyle style, BuildContext context) {
  final theme = Theme.of(context);
  return style.copyWith(
    color: theme.primaryColorLight,
    fontWeight: FontWeight.w300,
  );
}

/// Builds an [ErrorReporter] for a context that shows a [SnackBar].
ErrorReporter showErrorSnackBar(BuildContext context) {
  return (String title, dynamic error) {
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text(title),
    ));
  };
}
