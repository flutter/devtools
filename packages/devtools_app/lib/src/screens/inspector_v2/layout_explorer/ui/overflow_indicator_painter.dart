// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../inspector_data_models.dart';

/// CustomPainter for drawing [DebugOverflowIndicatorMixin]'s patterned background.
/// Draws overflow pattern on the [OverflowSide] of the widget.
///
/// [DebugOverflowIndicatorMixin] can not be reused here
/// because it is a mixin on RenderObject and requires real overflows on the widget.
///
/// If [side] is set to [OverflowSide.right],
/// the pattern will occupy the whole height
/// and the width will be the given [size].
///
/// If [side] is set to [OverflowSide.bottom],
/// the pattern will occupy the whole width
/// and the height will be the given [size].
///
/// See also:
/// * [DebugOverflowIndicatorMixin]
class OverflowIndicatorPainter extends CustomPainter {
  const OverflowIndicatorPainter(this.side, this.size);

  final OverflowSide side;
  final double size;

  /// These static variables  are taken from [DebugOverflowIndicatorMixin]
  /// since all of them are private.
  static const black = Color(0xBF000000);
  static const yellow = Color(0xBFFFFF00);
  static final indicatorPaint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0.0, 0.0),
      const Offset(10.0, 10.0),
      <Color>[black, yellow, yellow, black],
      <double>[0.25, 0.25, 0.75, 0.75],
      TileMode.repeated,
    );

  @override
  void paint(Canvas canvas, Size size) {
    final bottomOverflow = OverflowSide.bottom == side;
    final width = bottomOverflow ? size.width : this.size;
    final height = !bottomOverflow ? size.height : this.size;

    final left = bottomOverflow ? 0.0 : size.width - width;
    final top = side == OverflowSide.right ? 0.0 : size.height - height;
    final rect = Rect.fromLTWH(left, top, width, height);
    canvas.drawRect(rect, indicatorPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is OverflowIndicatorPainter &&
        (side != oldDelegate.side || size != oldDelegate.size);
  }
}
