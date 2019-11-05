// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const defaultArrowColor = Colors.white;
const defaultArrowHeadSize = 16.0;
const defaultArrowStrokeWidth = 2.0;
const defaultDistanceToArrow = 8.0;

enum ArrowType { up, left, right, down, body }

/// Widget that draws a bidirectional arrow around another widget.
///
/// This widget is typically used to help draw diagrams.
@immutable
class BidirectionalArrowWrapper extends StatelessWidget {
  BidirectionalArrowWrapper({
    Key key,
    @required this.child,
    @required this.direction,
    this.arrowColor = defaultArrowColor,
    this.arrowHeadSize = defaultArrowHeadSize,
    this.arrowStrokeWidth = defaultArrowStrokeWidth,
    double distanceToArrow = defaultDistanceToArrow,
  })  : assert(child != null),
        assert(direction != null),
        assert(arrowColor != null),
        assert(arrowHeadSize != null && arrowHeadSize > 0.0),
        assert(arrowStrokeWidth != null && arrowHeadSize > 0.0),
        assert(distanceToArrow != null && distanceToArrow > 0.0),
        distanceToArrow = direction == Axis.horizontal
            ? EdgeInsets.symmetric(horizontal: distanceToArrow)
            : EdgeInsets.symmetric(vertical: distanceToArrow),
        super(key: key);

  final Color arrowColor;
  final double arrowHeadSize;
  final double arrowStrokeWidth;
  final Widget child;

  final Axis direction;
  final EdgeInsets distanceToArrow;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: direction,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type: direction == Axis.horizontal ? ArrowType.left : ArrowType.up,
          ),
        ),
        Container(
          child: child,
          margin: distanceToArrow,
        ),
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type:
                direction == Axis.horizontal ? ArrowType.right : ArrowType.down,
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
    this.headSize = defaultArrowHeadSize,
    Key key,
    this.strokeWidth = defaultArrowStrokeWidth,
    @required this.type,
  })  : assert(color != null),
        assert(headSize != null && headSize > 0.0),
        assert(strokeWidth != null && strokeWidth > 0.0),
        assert(type != null),
        _painter = _ArrowPainter(
          headSize: headSize,
          color: color,
          strokeWidth: strokeWidth,
          type: type,
        ),
        super(key: key);

  final Color color;

  /// The arrow head is a Equilateral triangle
  final double headSize;

  final double strokeWidth;

  final ArrowType type;

  final CustomPainter _painter;

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
    this.headSize = defaultArrowHeadSize,
    this.strokeWidth = defaultArrowStrokeWidth,
    this.color = defaultArrowColor,
    @required this.type,
  })  : assert(headSize != null),
        assert(color != null),
        assert(strokeWidth != null),
        assert(type != null),
        // the height of an equilateral triangle
        headHeight = 0.5 * sqrt(3) * headSize;

  final double headSize;
  final double strokeWidth;
  final Color color;
  final ArrowType type;

  final double headHeight;

  Path headPath(Size size) {
    assert(type != ArrowType.body);
    Offset p1, p2, p3;
    final headSizeDividedBy2 = headSize / 2;
    switch (type) {
      case ArrowType.up:
        p1 = Offset.zero;
        p2 = Offset(-headSizeDividedBy2, headHeight);
        p3 = Offset(headSizeDividedBy2, headHeight);
        break;
      case ArrowType.left:
        p1 = Offset.zero;
        p2 = Offset(headHeight, -headSizeDividedBy2);
        p3 = Offset(headHeight, headSizeDividedBy2);
        break;
      case ArrowType.right:
        final startingX = size.width - headHeight;
        p1 = Offset(size.width, 0);
        p2 = Offset(startingX, -headSizeDividedBy2);
        p3 = Offset(startingX, headSizeDividedBy2);
        break;
      case ArrowType.down:
        final startingY = size.height - headHeight;
        p1 = Offset(0, size.height);
        p2 = Offset(-headSizeDividedBy2, startingY);
        p3 = Offset(headSizeDividedBy2, startingY);
        break;
      case ArrowType.body:
        break;
    }
    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
  }

  Offset lineStartingPoint(Size size) {
    Offset o = Offset.zero;
    switch (type) {
      case ArrowType.up:
        o = Offset(0, headHeight);
        break;
      case ArrowType.left:
        o = Offset(headHeight, 0);
        break;
      case ArrowType.right:
      case ArrowType.down:
      case ArrowType.body:
        o = Offset.zero;
        break;
    }
    return o;
  }

  Offset lineEndingPoint(Size size) {
    Offset o = Offset.zero;
    switch (type) {
      case ArrowType.up:
        o = Offset(0, size.height);
        break;
      case ArrowType.left:
        o = Offset(size.width, 0);
        break;
      case ArrowType.right:
        final arrowHeadStartingX = size.width - headHeight;
        o = Offset(arrowHeadStartingX, 0);
        break;
      case ArrowType.down:
        final headStartingY = size.height - headHeight;
        o = Offset(0, headStartingY);
        break;
      case ArrowType.body:
        o = Offset(size.width, size.height);
        break;
    }
    return o;
  }

  bool headIsGreaterThanConstraint(Size size) {
    final startingPoint = lineStartingPoint(size);
    final endingPoint = lineEndingPoint(size);
    if (type == ArrowType.left || type == ArrowType.right)
      return headHeight > (endingPoint.dx - startingPoint.dx + 1);
    return headHeight > (endingPoint.dy - startingPoint.dy + 1);
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
    if (type != ArrowType.body && !headIsGreaterThanConstraint(size)) {
      canvas.drawPath(headPath(size), paint);
    }
    canvas.drawLine(
      lineStartingPoint(size),
      lineEndingPoint(size),
      paint,
    );
  }
}
