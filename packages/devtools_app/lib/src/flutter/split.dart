// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef SizedBuilder = Widget Function(BuildContext, Size);

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
    @required this.axis,
    @required this.firstChild,
    @required this.secondChild,
    double initialFirstFraction,
  })  : initialFirstFraction = initialFirstFraction ?? 0.5,
        assert(axis != null),
        assert(firstChild != null),
        assert(secondChild != null),
        firstBuilder = null,
        secondBuilder = null,
        super(key: key);

  /// Builds a split oriented along [axis] that takes [SizedBuilder]s for its
  /// children.
  ///
  /// This allows custom behavior when the split reaches a small size.
  ///
  /// Use this constructor if you are running into overflow errors at small child
  /// sizes and want to prevent them.
  const Split.builder({
    Key key,
    @required this.axis,
    @required this.firstBuilder,
    @required this.secondBuilder,
    double initialFirstFraction,
  })  : initialFirstFraction = initialFirstFraction ?? 0.5,
        assert(axis != null),
        assert(firstBuilder != null),
        assert(secondBuilder != null),
        firstChild = null,
        secondChild = null,
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
  ///
  /// If null, [firstBuilder] will be used instead.
  ///
  /// Between [firstBuilder] and [firstChild], exactly one must be non-null.
  /// In other words, `(firstBuilder == null) != (firstChild == null)`.
  final Widget firstChild;

  /// The child that will be laid out last along [axis].
  ///
  /// If null, [secondBuilder] will be used instead.
  ///
  /// Between [secondBuilder] and [secondChild], exactly one must be non-null.
  /// In other words, `(secondBuilder == null) != (secondChild == null)`.
  final Widget secondChild;

  /// The builder for the first child along [axis].
  ///
  /// If null, [firstChild] will be used instead.
  ///
  /// Between [firstBuilder] and [firstChild], exactly one must be non-null.
  /// In other words, `(firstBuilder == null) != (firstChild == null)`.
  final SizedBuilder firstBuilder;

  /// The builder for the second child along [axis].
  ///
  /// If null, [secondChild] will be used instead.
  ///
  /// Between [secondBuilder] and [secondChild], exactly one must be non-null.
  /// In other words, `(secondBuilder == null) != (secondChild == null)`.
  final SizedBuilder secondBuilder;

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

  static Axis axisFor(BuildContext context, double horizontalAspectRatio) {
    final screenSize = MediaQuery.of(context).size;
    final aspectRatio = screenSize.width / screenSize.height;
    if (aspectRatio >= horizontalAspectRatio) return Axis.horizontal;
    return Axis.vertical;
  }

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

  Widget _buildFirstChild(Size size) {
    if (widget.firstChild != null) return widget.firstChild;
    return Builder(builder: (context) => widget.firstBuilder(context, size));
  }

  Widget _buildSecondChild(Size size) {
    if (widget.secondChild != null) return widget.secondChild;
    return Builder(builder: (context) => widget.secondBuilder(context, size));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildLayout);
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final axisSize = isHorizontal ? width : height;
    final crossAxisSize = isHorizontal ? height : width;
    const halfDivider = Split.dividerMainAxisSize / 2.0;

    // Determine what fraction to give each child, including enough space to
    // display the divider.
    double firstMainAxisSize = axisSize * firstFraction;
    double secondMainAxisSize = axisSize * secondFraction;

    // Clamp the sizes to be sure there is enough space for the dividers.
    firstMainAxisSize =
        firstMainAxisSize.clamp(halfDivider, axisSize - halfDivider);
    secondMainAxisSize =
        secondMainAxisSize.clamp(halfDivider, axisSize - halfDivider);

    // Remove space from each child to place the divider in the middle.
    firstMainAxisSize = firstMainAxisSize - halfDivider;
    secondMainAxisSize = secondMainAxisSize - halfDivider;

    void updateSpacing(DragUpdateDetails dragDetails) {
      final delta = isHorizontal ? dragDetails.delta.dx : dragDetails.delta.dy;
      final fractionalDelta = delta / axisSize;
      setState(() {
        // Update the fraction of space consumed by the children,
        // being sure not to allocate any negative space.
        firstFraction += fractionalDelta;
        firstFraction = firstFraction.clamp(0.0, 1.0);
      });
    }

    // TODO(https://github.com/flutter/flutter/issues/43747): use an icon.
    // The material icon for a drag handle is not currently available.
    // For now, draw an indicator that is 3 lines running in the direction
    // of the main axis, like a hamburger menu.
    // TODO(https://github.com/flutter/devtools/issues/1265): update mouse
    // to indicate that this is resizable.
    final dragIndicator = Flex(
      direction: isHorizontal ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < min(crossAxisSize / 6.0, 3).floor(); i++)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: isHorizontal ? 2.0 : 0.0,
              horizontal: isHorizontal ? 0.0 : 2.0,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(Split.dividerMainAxisSize),
              ),
              child: SizedBox(
                height: isHorizontal ? 2.0 : Split.dividerMainAxisSize - 2.0,
                width: isHorizontal ? Split.dividerMainAxisSize - 2.0 : 2.0,
              ),
            ),
          ),
      ],
    );
    final firstSize = Size(
      isHorizontal ? firstMainAxisSize : width,
      isHorizontal ? height : firstMainAxisSize,
    );
    final secondSize = Size(
      isHorizontal ? secondMainAxisSize : width,
      isHorizontal ? height : secondMainAxisSize,
    );
    final children = [
      SizedBox.fromSize(
        size: firstSize,
        child: _buildFirstChild(firstSize),
      ),
      GestureDetector(
        key: widget.dividerKey,
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: isHorizontal ? updateSpacing : null,
        onVerticalDragUpdate: isHorizontal ? null : updateSpacing,
        // DartStartBehavior.down is needed to keep the mouse pointer stuck to
        // the drag bar. There still appears to be a few frame lag before the
        // drag action triggers which is't ideal but isn't a launch blocker.
        dragStartBehavior: DragStartBehavior.down,
        child: SizedBox(
          width: isHorizontal ? Split.dividerMainAxisSize : width,
          height: isHorizontal ? height : Split.dividerMainAxisSize,
          child: Center(
            child: dragIndicator,
          ),
        ),
      ),
      SizedBox.fromSize(
        size: secondSize,
        child: _buildSecondChild(secondSize),
      ),
    ];
    return Flex(direction: widget.axis, children: children);
  }
}
