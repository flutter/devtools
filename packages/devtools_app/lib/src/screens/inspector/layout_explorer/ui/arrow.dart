// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

const defaultArrowColor = Colors.white;
const defaultArrowStrokeWidth = 2.0;
const defaultDistanceToArrow = 4.0;

enum ArrowType {
  up,
  left,
  right,
  down,
}

Axis axis(ArrowType type) => (type == ArrowType.up || type == ArrowType.down)
    ? Axis.vertical
    : Axis.horizontal;

/// Widget that draws a bidirectional arrow around another widget.
///
/// This widget is typically used to help draw diagrams.
@immutable
class ArrowWrapper extends StatelessWidget {
  ArrowWrapper.unidirectional({
    Key? key,
    this.child,
    required ArrowType type,
    this.arrowColor = defaultArrowColor,
    double? arrowHeadSize,
    this.arrowStrokeWidth = defaultArrowStrokeWidth,
    this.childMarginFromArrow = defaultDistanceToArrow,
  })  : assert(childMarginFromArrow > 0.0),
        direction = axis(type),
        isBidirectional = false,
        startArrowType = type,
        endArrowType = type,
        arrowHeadSize = arrowHeadSize ?? defaultIconSize,
        super(key: key);

  const ArrowWrapper.bidirectional({
    Key? key,
    this.child,
    required this.direction,
    this.arrowColor = defaultArrowColor,
    required this.arrowHeadSize,
    this.arrowStrokeWidth = defaultArrowStrokeWidth,
    this.childMarginFromArrow = defaultDistanceToArrow,
  })  : assert(arrowHeadSize >= 0.0),
        assert(childMarginFromArrow >= 0.0),
        isBidirectional = true,
        startArrowType =
            direction == Axis.horizontal ? ArrowType.left : ArrowType.up,
        endArrowType =
            direction == Axis.horizontal ? ArrowType.right : ArrowType.down,
        super(key: key);

  final Color arrowColor;
  final double arrowHeadSize;
  final double arrowStrokeWidth;
  final Widget? child;

  final Axis direction;
  final double childMarginFromArrow;

  final bool isBidirectional;
  final ArrowType startArrowType;
  final ArrowType endArrowType;

  double get verticalMarginFromArrow {
    if (child == null || direction == Axis.horizontal) return 0.0;
    return childMarginFromArrow;
  }

  double get horizontalMarginFromArrow {
    if (child == null || direction == Axis.vertical) return 0.0;
    return childMarginFromArrow;
  }

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: direction,
      children: <Widget>[
        Expanded(
          child: Container(
            margin: EdgeInsets.only(
              bottom: verticalMarginFromArrow,
              right: horizontalMarginFromArrow,
            ),
            child: ArrowWidget(
              color: arrowColor,
              headSize: arrowHeadSize,
              strokeWidth: arrowStrokeWidth,
              type: startArrowType,
              shouldDrawHead: isBidirectional
                  ? true
                  : (startArrowType == ArrowType.left ||
                      startArrowType == ArrowType.up),
            ),
          ),
        ),
        if (child != null) child!,
        Expanded(
          child: Container(
            margin: EdgeInsets.only(
              top: verticalMarginFromArrow,
              left: horizontalMarginFromArrow,
            ),
            child: ArrowWidget(
              color: arrowColor,
              headSize: arrowHeadSize,
              strokeWidth: arrowStrokeWidth,
              type: endArrowType,
              shouldDrawHead: isBidirectional
                  ? true
                  : (endArrowType == ArrowType.right ||
                      endArrowType == ArrowType.down),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget that draws a fully sized, centered, unidirectional arrow according to its constraints
@immutable
class ArrowWidget extends StatelessWidget {
  ArrowWidget({
    this.color = defaultArrowColor,
    required this.headSize,
    Key? key,
    this.shouldDrawHead = true,
    this.strokeWidth = defaultArrowStrokeWidth,
    required this.type,
  })  : assert(headSize > 0.0),
        assert(strokeWidth > 0.0),
        _painter = _ArrowPainter(
          headSize: headSize,
          color: color,
          strokeWidth: strokeWidth,
          type: type,
          shouldDrawHead: shouldDrawHead,
        ),
        super(key: key);

  final Color color;

  /// The arrow head is a Equilateral triangle
  final double headSize;

  final double strokeWidth;

  final ArrowType type;

  final CustomPainter _painter;

  final bool shouldDrawHead;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _painter,
      child: Container(),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    required this.headSize,
    this.strokeWidth = defaultArrowStrokeWidth,
    this.color = defaultArrowColor,
    this.shouldDrawHead = true,
    required this.type,
  }) : // the height of an equilateral triangle
        headHeight = 0.5 * sqrt(3) * headSize;

  final Color color;
  final double headSize;
  final bool shouldDrawHead;
  final double strokeWidth;
  final ArrowType type;

  final double headHeight;

  bool headIsGreaterThanConstraint(Size size) {
    if (type == ArrowType.left || type == ArrowType.right) {
      return headHeight >= (size.width);
    }
    return headHeight >= (size.height);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) =>
      !(oldDelegate is _ArrowPainter &&
          headSize == oldDelegate.headSize &&
          strokeWidth == oldDelegate.strokeWidth &&
          color == oldDelegate.color &&
          type == oldDelegate.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    final originX = size.width / 2, originY = size.height / 2;
    Offset lineStartingPoint = Offset.zero;
    Offset lineEndingPoint = Offset.zero;

    if (!headIsGreaterThanConstraint(size) && shouldDrawHead) {
      Offset p1, p2, p3;
      final headSizeDividedBy2 = headSize / 2;
      switch (type) {
        case ArrowType.up:
          p1 = Offset(originX, 0);
          p2 = Offset(originX - headSizeDividedBy2, headHeight);
          p3 = Offset(originX + headSizeDividedBy2, headHeight);
          break;
        case ArrowType.left:
          p1 = Offset(0, originY);
          p2 = Offset(headHeight, originY - headSizeDividedBy2);
          p3 = Offset(headHeight, originY + headSizeDividedBy2);
          break;
        case ArrowType.right:
          final startingX = size.width - headHeight;
          p1 = Offset(size.width, originY);
          p2 = Offset(startingX, originY - headSizeDividedBy2);
          p3 = Offset(startingX, originY + headSizeDividedBy2);
          break;
        case ArrowType.down:
          final startingY = size.height - headHeight;
          p1 = Offset(originX, size.height);
          p2 = Offset(originX - headSizeDividedBy2, startingY);
          p3 = Offset(originX + headSizeDividedBy2, startingY);
          break;
      }
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      canvas.drawPath(path, paint);

      switch (type) {
        case ArrowType.up:
          lineStartingPoint = Offset(originX, headHeight);
          lineEndingPoint = Offset(originX, size.height);
          break;
        case ArrowType.left:
          lineStartingPoint = Offset(headHeight, originY);
          lineEndingPoint = Offset(size.width, originY);
          break;
        case ArrowType.right:
          final arrowHeadStartingX = size.width - headHeight;
          lineStartingPoint = Offset(0, originY);
          lineEndingPoint = Offset(arrowHeadStartingX, originY);
          break;
        case ArrowType.down:
          final headStartingY = size.height - headHeight;
          lineStartingPoint = Offset(originX, 0);
          lineEndingPoint = Offset(originX, headStartingY);
          break;
      }
    } else {
      // draw full line
      switch (type) {
        case ArrowType.up:
        case ArrowType.down:
          lineStartingPoint = Offset(originX, 0);
          lineEndingPoint = Offset(originX, size.height);
          break;
        case ArrowType.left:
        case ArrowType.right:
          lineStartingPoint = Offset(0, originY);
          lineEndingPoint = Offset(size.width, originY);
          break;
      }
    }
    canvas.drawLine(
      lineStartingPoint,
      lineEndingPoint,
      paint,
    );
  }
}
