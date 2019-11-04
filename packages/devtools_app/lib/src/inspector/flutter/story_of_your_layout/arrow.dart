// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

enum ArrowType { up, left, right, down }

/// Widget that wraps and center another widget horizontally with bidirectional arrow (left & right)
@immutable
class BidirectionalHorizontalArrowWrapper extends StatelessWidget {
  const BidirectionalHorizontalArrowWrapper({
    Key key,
    this.arrowColor = Colors.white,
    this.arrowHeadSize = 16.0,
    this.arrowStrokeWidth = 2.0,
    @required this.child,
  })  : assert(child != null),
        super(key: key);

  final Color arrowColor;
  final double arrowHeadSize;
  final double arrowStrokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type: ArrowType.left,
          ),
        ),
        Container(
          child: child,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
        ),
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type: ArrowType.right,
          ),
        ),
      ],
    );
  }
}

/// Widget that wraps and center another widget vertically with bidirectional arrow (up & down)
@immutable
class BidirectionalVerticalArrowWrapper extends StatelessWidget {
  const BidirectionalVerticalArrowWrapper({
    Key key,
    @required this.child,
    this.arrowColor = Colors.white,
    this.arrowHeadSize = 16.0,
    this.arrowStrokeWidth = 2.0,
  })  : assert(child != null),
        super(key: key);

  final Color arrowColor;
  final double arrowHeadSize;
  final double arrowStrokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type: ArrowType.up,
          ),
        ),
        Container(
          child: child,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
        ),
        Expanded(
          child: ArrowWidget(
            color: arrowColor,
            headSize: arrowHeadSize,
            strokeWidth: arrowStrokeWidth,
            type: ArrowType.down,
          ),
        ),
      ],
    );
  }
}

/// Widget that draws a fully sized, centered, unidirectional arrow according to its constraints
@immutable
class ArrowWidget extends StatelessWidget {
  const ArrowWidget({
    this.color = Colors.white,
    this.headSize = 16.0,
    Key key,
    this.strokeWidth = 2.0,
    @required this.type,
  })  : assert(color != null),
        assert(headSize != null),
        assert(strokeWidth != null),
        assert(type != null),
        super(key: key);

  final Color color;

  /// The arrow head is a Equilateral triangle
  final double headSize;

  final double strokeWidth;

  final ArrowType type;

  CustomPainter get _painter => _ArrowPainter(
        arrowHeadSize: headSize,
        color: color,
        strokeWidth: strokeWidth,
        strategy: _ArrowPaintStrategy.strategy(type),
      );

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _painter,
      child: Container(),
    );
  }
}

abstract class _ArrowPaintStrategy {
  void paint({
    @required Canvas canvas,
    @required Size size,
    @required Paint paint,
    @required double headSize,
  });

  static final _ArrowPaintStrategy _up = _UpwardsArrowPaintStrategy();
  static final _ArrowPaintStrategy _left = _LeftwardsArrowPaintStrategy();
  static final _ArrowPaintStrategy _down = _DownwardsArrowPaintStrategy();
  static final _ArrowPaintStrategy _right = _RightwardsArrowPaintStrategy();

  static Path pathForArrowHead(Offset p1, Offset p2, Offset p3) {
    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
  }

  static _ArrowPaintStrategy strategy(ArrowType type) {
    switch (type) {
      case ArrowType.up:
        return _up;
      case ArrowType.left:
        return _left;
      case ArrowType.right:
        return _right;
      case ArrowType.down:
        return _down;
      default:
        return _up;
    }
  }
}

class _UpwardsArrowPaintStrategy implements _ArrowPaintStrategy {
  @override
  void paint({Canvas canvas, Size size, Paint paint, double headSize}) {
    final arrowHeadSizeDividedByTwo = headSize / 2;
    final p1 = Offset.zero;
    final p2 = Offset(-arrowHeadSizeDividedByTwo, headSize);
    final p3 = Offset(arrowHeadSizeDividedByTwo, headSize);
    canvas.drawPath(_ArrowPaintStrategy.pathForArrowHead(p1, p2, p3), paint);
    final lineStartingPoint = Offset(0, headSize);
    final lineEndingPoint = Offset(0, size.height);
    canvas.drawLine(lineStartingPoint, lineEndingPoint, paint);
  }
}

class _LeftwardsArrowPaintStrategy implements _ArrowPaintStrategy {
  @override
  void paint({Canvas canvas, Size size, Paint paint, double headSize}) {
    final arrowHeadSizeDividedByTwo = headSize / 2;
    final p1 = Offset.zero;
    final p2 = Offset(headSize, -arrowHeadSizeDividedByTwo);
    final p3 = Offset(headSize, arrowHeadSizeDividedByTwo);
    canvas.drawPath(_ArrowPaintStrategy.pathForArrowHead(p1, p2, p3), paint);
    final lineStartingPoint = Offset(headSize, 0);
    final lineEndingPoint = Offset(size.width, 0);
    canvas.drawLine(lineStartingPoint, lineEndingPoint, paint);
  }
}

class _DownwardsArrowPaintStrategy implements _ArrowPaintStrategy {
  @override
  void paint({Canvas canvas, Size size, Paint paint, double headSize}) {
    final arrowHeadSizeDividedByTwo = headSize / 2;
    final arrowHeadStartingY = size.height - headSize;
    final lineStartingPoint = Offset.zero;
    final lineEndingPoint = Offset(0, arrowHeadStartingY);
    canvas.drawLine(lineStartingPoint, lineEndingPoint, paint);
    final p1 = Offset(0, size.height);
    final p2 = Offset(-arrowHeadSizeDividedByTwo, arrowHeadStartingY);
    final p3 = Offset(arrowHeadSizeDividedByTwo, arrowHeadStartingY);
    canvas.drawPath(_ArrowPaintStrategy.pathForArrowHead(p1, p2, p3), paint);
  }
}

class _RightwardsArrowPaintStrategy implements _ArrowPaintStrategy {
  @override
  void paint({Canvas canvas, Size size, Paint paint, double headSize}) {
    final arrowHeadSizeDividedByTwo = headSize / 2;
    final arrowHeadStartingX = size.width - headSize;
    final lineStartingPoint = Offset.zero;
    final lineEndingPoint = Offset(arrowHeadStartingX, 0);
    canvas.drawLine(lineStartingPoint, lineEndingPoint, paint);
    final p1 = Offset(size.width, 0);
    final p2 = Offset(arrowHeadStartingX, -arrowHeadSizeDividedByTwo);
    final p3 = Offset(arrowHeadStartingX, arrowHeadSizeDividedByTwo);
    canvas.drawPath(_ArrowPaintStrategy.pathForArrowHead(p1, p2, p3), paint);
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({
    this.arrowHeadSize = 15.0,
    this.strokeWidth = 2.0,
    this.color = Colors.white,
    @required this.strategy,
  })  : assert(color != null),
        assert(arrowHeadSize != null),
        assert(strokeWidth != null),
        assert(strategy != null);

  final double arrowHeadSize;
  final double strokeWidth;
  final Color color;
  final _ArrowPaintStrategy strategy;

  @override
  bool shouldRepaint(CustomPainter oldDelegate) =>
      !(oldDelegate is _ArrowPainter &&
          arrowHeadSize == oldDelegate.arrowHeadSize &&
          strokeWidth == oldDelegate.strokeWidth &&
          color == oldDelegate.color &&
          strategy == oldDelegate.strategy);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;

    strategy.paint(
      canvas: canvas,
      size: size,
      paint: paint,
      headSize: arrowHeadSize,
    );
  }
}
