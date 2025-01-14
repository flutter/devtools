// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

// TODO(polina-c): use the same constants as for dash in the chart.
const _dashHeight = 2.0;
const _dashWidth = 5.0;
const _spaceBetweenDash = 3.0;

Widget createDashWidget(Color color) {
  final dash = Container(width: _dashWidth, height: _dashHeight, color: color);
  const space = SizedBox(width: _spaceBetweenDash, height: _dashHeight);
  return Row(children: [dash, space, dash, space, dash]);
}

Widget createSolidLine(Color color) {
  return Container(
    height: 6,
    width: 20,
    color: color,
    margin: const EdgeInsets.symmetric(horizontal: 1.0),
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
    _color = color ?? (Colors.grey.shade500);
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
    final paint =
        Paint()
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
