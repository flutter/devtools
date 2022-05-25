// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

const _totalDashWidth = 15.0;
const _dashHeight = 2.0;
const _dashWidth = 4.0;
const _spaceBetweenDash = 3.0;

Widget createDashWidget(Color color) {
  return Container(
    padding: const EdgeInsets.only(right: 20),
    child: CustomPaint(
      painter: DashedLine(
        _totalDashWidth,
        color,
        _dashHeight,
        _dashWidth,
        _spaceBetweenDash,
      ),
      foregroundPainter: DashedLine(
        _totalDashWidth,
        color,
        _dashHeight,
        _dashWidth,
        _spaceBetweenDash,
      ),
    ),
  );
}

Widget createSolidLine(Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 1.0),
    child: Container(
      height: 6,
      width: 20,
      color: color,
    ),
  );
}

/// Draw a dashed line on the canvas.
class DashedLine extends CustomPainter {
  DashedLine(
    this._totalWidth, [
    Color? color,
    this._dashHeight = defaultDashHeight,
    this._dashWidth = defaultDashWidth,
    this._dashSpace = defaultDashSpace,
  ]) {
    _color = color == null ? (Colors.grey.shade500) : color;
  }

  static const defaultDashHeight = 1.0;
  static const defaultDashWidth = 5.0;
  static const defaultDashSpace = 5.0;

  final double _dashHeight;
  final double _dashWidth;
  final double _dashSpace;

  double _totalWidth;
  late Color _color;

  @override
  void paint(Canvas canvas, Size size) {
    double startX = 0;
    final paint = Paint()
      ..color = _color
      ..strokeWidth = _dashHeight;

    while (_totalWidth >= 0) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + _dashWidth, 0), paint);
      final space = _dashSpace + _dashWidth;
      startX += space;
      _totalWidth -= space;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
