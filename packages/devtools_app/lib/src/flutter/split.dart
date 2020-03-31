// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/gestures.dart';
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
  Split({
    Key key,
    @required this.axis,
    @required this.children,
    @required this.initialFractions,
  })  : assert(axis != null),
        assert(children != null && children.length >= 2),
        assert(initialFractions != null && initialFractions.length >= 2),
        assert(children.length == initialFractions.length),
        super(key: key) {
    var sumFractions = 0.0;
    for (var fraction in initialFractions) {
      sumFractions += fraction;
    }
    assert(sumFractions == 1.0);
  }

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

  /// The children that will be laid out along [axis].
  final List<Widget> children;

  /// The fraction of the layout to allocate to each child in [children].
  ///
  /// The index of [initialFractions] corresponds to the child at index of
  /// [children].
  final List<double> initialFractions;

  /// The key passed to the divider(s) between each child in [children].
  ///
  /// Visible to grab it in tests.
  @visibleForTesting
  Key dividerKey(int index) => Key('$this dividerKey $index');

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
  List<double> fractions;

  bool get isHorizontal => widget.axis == Axis.horizontal;

  @override
  void initState() {
    super.initState();
    fractions = List.from(widget.initialFractions);
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

    // Determine what fraction to give each child, including enough space to
    // display the divider.
    final numDividers = widget.children.length - 1;
    final sizes = List.generate(
      fractions.length,
      (i) =>
          (axisSize - numDividers * Split.dividerMainAxisSize) * fractions[i],
    );

    void updateSpacing(DragUpdateDetails dragDetails, int splitterIndex) {
      final dragDelta =
          isHorizontal ? dragDetails.delta.dx : dragDetails.delta.dy;
      final fractionalDelta = dragDelta / axisSize;

      double updateSpacingBeforeSplitterIndex(double delta) {
        var index = splitterIndex;
        while (index >= 0) {
          fractions[index] += delta;
          if (fractions[index] >= 0.0) {
            _clampFraction(index);
            return 0.0;
          }
          delta = fractions[index];
          _clampFraction(index);
          index--;
        }
        return delta;
      }

      double updateSpacingAfterSplitterIndex(double delta) {
        var index = splitterIndex + 1;
        while (index < fractions.length) {
          fractions[index] += delta;
          if (fractions[index] >= 0.0) {
            _clampFraction(index);
            return 0.0;
          }
          delta = fractions[index];
          _clampFraction(index);
          index++;
        }
        return delta;
      }

      setState(() {
        // Update the fraction of space consumed by the children. Always update
        // the shrinking children first so that we do not over-increase the size
        // of the growing children and cause layout overflow errors.
        if (fractionalDelta <= 0.0) {
          final overflowDelta =
              updateSpacingBeforeSplitterIndex(fractionalDelta);
          final actualDelta = overflowDelta != 0.0
              ? fractionalDelta - overflowDelta
              : fractionalDelta;
          updateSpacingAfterSplitterIndex(-actualDelta);
        } else {
          final overflowDelta =
              updateSpacingAfterSplitterIndex(-fractionalDelta);
          final actualDelta = overflowDelta != 0.0
              ? fractionalDelta + overflowDelta
              : fractionalDelta;
          updateSpacingBeforeSplitterIndex(actualDelta);
        }
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

    final children = <Widget>[];
    for (int i = 0; i < widget.children.length; i++) {
      children.addAll([
        SizedBox(
          width: isHorizontal ? sizes[i] : width,
          height: isHorizontal ? height : sizes[i],
          child: widget.children[i],
        ),
        if (i < widget.children.length - 1)
          GestureDetector(
            key: widget.dividerKey(i),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) =>
                isHorizontal ? updateSpacing(details, i) : null,
            onVerticalDragUpdate: (details) =>
                isHorizontal ? null : updateSpacing(details, i),
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
      ]);
    }
    return Flex(direction: widget.axis, children: children);
  }

  void _clampFraction(int index) {
    fractions[index] = fractions[index].clamp(0.0, 1.0);
  }
}
