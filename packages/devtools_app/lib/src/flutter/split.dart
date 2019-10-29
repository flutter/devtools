// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// A widget that takes two children, lays them out along [axis], and allows
/// the user to resize them.
///
/// The user can customize the amount of space allocated to each child by
/// dragging a divider between them.
///
/// [initialFirstFraction] defines how much space to give the [firstChild]
/// when first building this widget. [secondChild] will take the remaining
/// space.
///
/// The user can drag the widget with key [dividerKey] to change
/// the space allocated between [firstChild] and [secondChild].
// TODO(djshuckerow): introduce support for a minimum fraction a child is allowed.
class Split extends StatefulWidget {
  /// Builds a split oriented along [axis].
  const Split({
    Key key,
    this.axis,
    this.firstChild,
    this.secondChild,
    double initialFirstFraction,
  })  : initialFirstFraction = initialFirstFraction ?? 0.5,
        assert(axis != null),
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
    final axisSize = isHorizontal ? width : height;
    const halfDivider = Split.dividerMainAxisSize / 2.0;
    // The fraction of the layout the divider needs to take up from each child.
    final halfDividerFraction = halfDivider / axisSize;

    final sanitizedFirstFraction =
        firstFraction.clamp(halfDividerFraction, 1.0 - halfDividerFraction);
    final sanitizedSecondFraction =
        secondFraction.clamp(halfDividerFraction, 1.0 - halfDividerFraction);

    final firstSize = axisSize * sanitizedFirstFraction - halfDivider;
    final secondSize = axisSize * sanitizedSecondFraction - halfDivider;

    void updateSpacing(DragUpdateDetails dragDetails) {
      final delta = isHorizontal ? dragDetails.delta.dx : dragDetails.delta.dy;
      final fractionalDelta = delta / axisSize;
      setState(() {
        // Update the fraction of space consumed by the children,
        // being sure not to allocate any of them negative space.
        firstFraction += fractionalDelta;
        firstFraction = firstFraction.clamp(0.0, 1.0);
      });
    }

    final children = [
      SizedBox(
        width: isHorizontal ? firstSize : width,
        height: isHorizontal ? height : firstSize,
        child: widget.firstChild,
      ),
      GestureDetector(
        key: widget.dividerKey,
        onHorizontalDragUpdate: isHorizontal ? updateSpacing : null,
        onVerticalDragUpdate: isHorizontal ? null : updateSpacing,
        child: SizedBox(
          width: isHorizontal ? Split.dividerMainAxisSize : width,
          height: isHorizontal ? height : Split.dividerMainAxisSize,
          child: const Center(
            child: Text(
              ':::::::',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      SizedBox(
        width: isHorizontal ? secondSize : width,
        height: isHorizontal ? height : secondSize,
        child: widget.secondChild,
      ),
    ];
    return Flex(direction: widget.axis, children: children);
  }
}
