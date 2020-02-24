import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/marker/i_marker.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/value_formatter/default_value_formatter.dart';

class LineChartMarker implements IMarker {
  Entry _entry;
  // ignore: unused_field
  Highlight _highlight;
  double _dx = 0.0;
  double _dy = 0.0;

  DefaultValueFormatter _formatter;
  Color _textColor;
  Color _backColor;
  double _fontSize;

  LineChartMarker({Color textColor, Color backColor, double fontSize})
      : _textColor = textColor,
        _backColor = backColor,
        _fontSize = fontSize {
    _formatter = DefaultValueFormatter(0);
    this._textColor ??= ColorUtils.PURPLE;
//    _backColor ??= Color.fromARGB((_textColor.alpha * 0.5).toInt(),
//        _textColor.red, _textColor.green, _textColor.blue);
    this._backColor ??= ColorUtils.WHITE;
    this._fontSize ??= Utils.convertDpToPixel(10);
  }

  @override
  void draw(Canvas canvas, double posX, double posY) {
    TextPainter painter = PainterUtils.create(
        null,
        "${_formatter.getFormattedValue1(_entry.x)},${_formatter.getFormattedValue1(_entry.y)}",
        _textColor,
        _fontSize);
    Paint paint = Paint()
      ..color = _backColor
      ..strokeWidth = 2
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    MPPointF offset = getOffsetForDrawingAtPoint(posX, posY);

    canvas.save();
    // translate to the correct position and draw
//    canvas.translate(posX + offset.x, posY + offset.y);
    painter.layout();
    Offset pos = calculatePos(
        posX + offset.x, posY + offset.y, painter.width, painter.height);
    canvas.drawRRect(
        RRect.fromLTRBR(pos.dx - 5, pos.dy - 5, pos.dx + painter.width + 5,
            pos.dy + painter.height + 5, Radius.circular(5)),
        paint);
    painter.paint(canvas, pos);
    canvas.restore();
  }

  Offset calculatePos(double posX, double posY, double textW, double textH) {
    return Offset(posX - textW / 2, posY - textH / 2);
  }

  @override
  MPPointF getOffset() {
    return MPPointF.getInstance1(_dx, _dy);
  }

  @override
  MPPointF getOffsetForDrawingAtPoint(double posX, double posY) {
    return getOffset();
  }

  @override
  void refreshContent(Entry e, Highlight highlight) {
    _entry = e;
    highlight = highlight;
  }
}
