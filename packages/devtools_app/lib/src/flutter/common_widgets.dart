// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widgets/flutter_widgets.dart';

/// Convenience [Divider] with [Padding] that provides a good divider in forms.
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
      textAlign: textAlign,
      style: defaultTextStyle,
    );
  }
}

/// A widget that takes two children and lays them out along one axis.
///
/// The user can customize the amount of space allocated to each child by
/// dragging a divider between them.
class Split extends StatefulWidget {
  /// Builds a [Split] with [Axis.horizontal] direction.
  ///
  /// [firstChild] will be placed before [secondChild] in a [Row].
  const Split.horizontal({
    Key key,
    @required Widget firstChild,
    @required Widget secondChild,
    double initialFirstFraction,
  }) : this._(
          key,
          Axis.horizontal,
          firstChild,
          secondChild,
          initialFirstFraction,
        );

  /// Builds a [Split] with [Axis.vertical] direction.
  ///
  /// [firstChild] will be placed before [secondChild] in a [Column].
  const Split.vertical({
    Key key,
    @required Widget firstChild,
    @required Widget secondChild,
    double initialFirstFraction,
  }) : this._(
          key,
          Axis.vertical,
          firstChild,
          secondChild,
          initialFirstFraction,
        );

  const Split._(
    Key key,
    this.axis,
    this.firstChild,
    this.secondChild,
    double initialFirstFraction,
  )   : initialFirstFraction = initialFirstFraction ?? 0.5,
        super(key: key);

  /// The main axis the children will lay out on.
  ///
  /// If [Axis.horizontal], the children will be placed in a [Row]
  /// and they will be horizontally resizable.
  ///
  /// If [Axis.vertical], the children will be placed in a [Column]
  /// and they will be vertically resizable.
  ///
  /// Cannot be null.
  final Axis axis;

  /// The child that will be laid out first along [axis].
  final Widget firstChild;

  /// The child that will be laid out last along [axis].
  final Widget secondChild;

  /// The fraction of the layout to allocate to [firstChild].
  ///
  /// [secondChild] will receive a fraction of `1 - initialFirstFraction`.
  final double initialFirstFraction;

  /// The key passed to the divider between [firstChild] and [secondChild].
  ///
  /// Visible to grab it in tests.
  @visibleForTesting
  Key get dividerKey => Key('$this dividerKey');

  /// The size of the divider between [firstChild] and [secondChild] in
  /// logical pixels (dp, not px).
  static const double dividerMainAxisSize = 10.0;

  @override
  State<StatefulWidget> createState() => _SplitState();
}

class _SplitState extends State<Split> {
  double firstFraction;
  double get secondFraction => 1 - firstFraction;
  bool get isHorizontal => widget.axis == Axis.horizontal;

  @override
  void initState() {
    super.initState();
    firstFraction = widget.initialFirstFraction;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildLayout);
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    const halfDivider = Split.dividerMainAxisSize / 2.0;
    final spacerFraction = isHorizontal
        ? Split.dividerMainAxisSize / width
        : Split.dividerMainAxisSize / height;

    void updateSpacing(DragUpdateDetails dragDetails) {
      final delta = dragDetails.delta;
      final fractionalDelta =
          isHorizontal ? delta.dx / width : delta.dy / height;
      setState(() {
        firstFraction = max(
          spacerFraction,
          min(1.0 - spacerFraction, firstFraction + fractionalDelta),
        );
      });
    }

    final children = [
      SizedBox(
        width: isHorizontal ? firstFraction * width - halfDivider : width,
        height: isHorizontal ? height : firstFraction * height - halfDivider,
        child: widget.firstChild,
      ),
      SizedBox(
        width: isHorizontal ? Split.dividerMainAxisSize : width,
        height: isHorizontal ? height : Split.dividerMainAxisSize,
        child: Center(
          child: GestureDetector(
            onHorizontalDragUpdate: isHorizontal ? updateSpacing : null,
            onVerticalDragUpdate: isHorizontal ? null : updateSpacing,
            child: Text(
              ':::::::',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      SizedBox(
        width: isHorizontal ? secondFraction * width - halfDivider : width,
        height: isHorizontal ? height : secondFraction * height - halfDivider,
        child: widget.secondChild,
      ),
    ];
    if (widget.axis == Axis.horizontal) {
      return Row(
        children: [
          Expanded(
            child: Row(children: children),
          )
        ],
      );
    } else {
      return Column(
        children: [
          Expanded(
            child: Row(children: children),
          )
        ],
      );
    }
  }
}
