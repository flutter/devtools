import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/poolable/size.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/utils/screen_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/default_value_formatter.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';

abstract class Utils {
  static double DEG2RAD = pi / 180.0;

  static double FLOAT_EPSILON = 1.4E-45;

  static void drawXAxisValue(
      Canvas c,
      String text,
      double x,
      double y,
      TextPainter paint,
      MPPointF anchor,
      double angleDegrees,
      XAxisPosition position) {
    double drawOffsetX = 0;
    double drawOffsetY = 0;

    var originalTextAlign = paint.textAlign;
    paint.textAlign = TextAlign.left;

    if (angleDegrees != 0) {
      double translateX = x;
      double translateY = y;

      c.save();
      c.translate(translateX, translateY);
      c.rotate(angleDegrees);

      paint.text = TextSpan(text: text, style: paint.text.style);
      paint.layout();
      switch (position) {
        case XAxisPosition.BOTTOM:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.BOTTOM_INSIDE:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.TOP:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.TOP_INSIDE:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.BOTH_SIDED:
          break;
      }

      c.restore();
    } else {
      drawOffsetX += x;
      drawOffsetY += y;

      paint.text = TextSpan(text: text, style: paint.text.style);
      paint.layout();
      switch (position) {
        case XAxisPosition.BOTTOM:
          paint.paint(c, Offset(drawOffsetX - paint.width / 2, drawOffsetY));
          break;
        case XAxisPosition.BOTTOM_INSIDE:
          paint.paint(
              c,
              Offset(
                  drawOffsetX - paint.width / 2, drawOffsetY - paint.height));
          break;
        case XAxisPosition.TOP:
          paint.paint(
              c,
              Offset(
                  drawOffsetX - paint.width / 2, drawOffsetY - paint.height));
          break;
        case XAxisPosition.TOP_INSIDE:
          paint.paint(c, Offset(drawOffsetX - paint.width / 2, drawOffsetY));
          break;
        case XAxisPosition.BOTH_SIDED:
          break;
      }
    }

    paint.textAlign = originalTextAlign;
  }

  static void drawRadarXAxisValue(
      Canvas c,
      String text,
      double x,
      double y,
      TextPainter paint,
      MPPointF anchor,
      double angleDegrees,
      XAxisPosition position) {
    var originalTextAlign = paint.textAlign;
    paint.textAlign = TextAlign.left;
    double drawOffsetX = 0;
    double drawOffsetY = 0;
    if (angleDegrees != 0) {
      double translateX = x;
      double translateY = y;

      c.save();
      c.translate(translateX, translateY);
      c.rotate(angleDegrees);

      paint.text = TextSpan(text: text, style: paint.text.style);
      paint.layout();
      switch (position) {
        case XAxisPosition.BOTTOM:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.BOTTOM_INSIDE:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.TOP:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.TOP_INSIDE:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.BOTH_SIDED:
          break;
      }

      c.restore();
    } else {
      drawOffsetX += x;
      drawOffsetY += y;

      paint.text = TextSpan(text: text, style: paint.text.style);
      paint.layout();
      paint.paint(c, Offset(drawOffsetX - paint.width / 2, drawOffsetY));
    }
    paint.textAlign = originalTextAlign;
  }

  static void drawXAxisValueHorizontal(
      Canvas c,
      String text,
      double x,
      double y,
      TextPainter paint,
      MPPointF anchor,
      double angleDegrees,
      XAxisPosition position) {
    double drawOffsetX = 0;
    double drawOffsetY = 0;

    var originalTextAlign = paint.textAlign;
    paint.textAlign = TextAlign.left;

    if (angleDegrees != 0) {
      double translateX = x;
      double translateY = y;

      c.save();
      c.translate(translateX, translateY);
      c.rotate(angleDegrees);

      paint.text = TextSpan(text: text, style: paint.text.style);
      paint.layout();
      switch (position) {
        case XAxisPosition.BOTTOM:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.BOTTOM_INSIDE:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.TOP:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.TOP_INSIDE:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY));
          break;
        case XAxisPosition.BOTH_SIDED:
          break;
      }

      c.restore();
    } else {
      drawOffsetX += x;
      drawOffsetY += y;

      paint.text = TextSpan(text: text, style: paint.text.style);
      paint.layout();
      switch (position) {
        case XAxisPosition.BOTTOM:
          paint.paint(
              c,
              Offset(
                  drawOffsetX - paint.width, drawOffsetY - paint.height / 2));
          break;
        case XAxisPosition.BOTTOM_INSIDE:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY - paint.height / 2));
          break;
        case XAxisPosition.TOP:
          paint.paint(c, Offset(drawOffsetX, drawOffsetY - paint.height / 2));
          break;
        case XAxisPosition.TOP_INSIDE:
          paint.paint(
              c,
              Offset(
                  drawOffsetX - paint.width, drawOffsetY - paint.height / 2));
          break;
        case XAxisPosition.BOTH_SIDED:
          break;
      }
    }

    paint.textAlign = originalTextAlign;
  }

  static double FDEG2RAD = (pi / 180);

  static FSize getSizeOfRotatedRectangleByDegrees(
      double rectangleWidth, double rectangleHeight, double degrees) {
    final double radians = degrees * FDEG2RAD;
    return getSizeOfRotatedRectangleByRadians2(
        rectangleWidth, rectangleHeight, radians);
  }

  static FSize getSizeOfRotatedRectangleByRadians1(
      FSize rectangleSize, double radians) {
    return getSizeOfRotatedRectangleByRadians2(
        rectangleSize.width, rectangleSize.height, radians);
  }

  static FSize getSizeOfRotatedRectangleByRadians2(
      double rectangleWidth, double rectangleHeight, double radians) {
    return FSize.getInstance(
        (rectangleWidth * cos(radians)).abs() +
            (rectangleHeight * sin(radians)).abs(),
        (rectangleWidth * sin(radians)).abs() +
            (rectangleHeight * cos(radians)).abs());
  }

  static FSize calcTextSize3(TextPainter paint, String demoText) {
    FSize result = FSize.getInstance(0, 0);
    calcTextSize4(paint, demoText, result);
    return result;
  }

  static void calcTextSize4(
      TextPainter paint, String demoText, FSize outputFSize) {
    paint.text = TextSpan(text: demoText, style: paint.text.style);
    paint.layout();
    outputFSize.width = paint.width;
    outputFSize.height = paint.height;
  }

  static double nextUp(double d) {
    if (d == double.infinity)
      return d;
    else {
      d += 0.1;
//      todo return longBitsToDouble(doubleToRawLongBits(d) +
//          ((d >= 0.0) ? 1 : -1));
      return d;
    }
  }

  static ValueFormatter mDefaultValueFormatter =
      _generateDefaultValueFormatter();

  static ValueFormatter _generateDefaultValueFormatter() {
    return new DefaultValueFormatter(1);
  }

  static ValueFormatter getDefaultValueFormatter() {
    return mDefaultValueFormatter;
  }

  static double convertDpToPixel(double dp) {
    return ScreenUtils.getInstance().getSp(dp);
  }

  static int calcTextWidth(TextPainter p, String demoText) {
    TextPainter painter = PainterUtils.create(
        p, demoText, p.text.style.color, p.text.style.fontSize);
    painter.layout();
    return painter.width.toInt();
  }

  static int calcTextHeight(TextPainter p, String demoText) {
    TextPainter painter = PainterUtils.create(
        p, demoText, p.text.style.color, p.text.style.fontSize);
    painter.layout();
    return painter.height.toInt();
  }

  static FSize calcTextSize1(TextPainter p, String demoText) {
    FSize result = FSize.getInstance(0, 0);
    calcTextSize2(p, demoText, result);
    return result;
  }

  static void calcTextSize2(TextPainter p, String demoText, FSize outputFSize) {
    TextPainter painter = PainterUtils.create(
        p, demoText, p.text.style.color, p.text.style.fontSize);
    painter.layout();
    outputFSize.width = painter.width;
    outputFSize.height = painter.height;
  }

  static double getLineHeight1(TextPainter paint) {
    return getLineHeight2(paint);
  }

  static double getLineHeight2(TextPainter paint) {
    paint.layout();
    return paint.height;
  }

  static double getLineSpacing1(TextPainter paint) {
    return getLineSpacing2(paint);
  }

  static double getLineSpacing2(TextPainter paint) {
    // todo return fontMetrics.ascent - fontMetrics.top + fontMetrics.bottom;
    paint.layout();
    return paint.height * 0.5;
  }

  static int getDecimals(double number) {
    double i = roundToNextSignificant(number);
    if (i.isInfinite || i == 0.0) return 0;

    return (-log(i) / ln10).ceil().toInt() + 2;
  }

  static double roundToNextSignificant(double number) {
    if (number.isInfinite || number.isNaN || number == 0.0) return 0;

    final double d =
        (log(number < 0 ? -number : number) / ln10).ceil().toDouble();
    final int pw = 1 - d.toInt();
    final double magnitude = pow(10.0, pw);
    final int shifted = (number * magnitude).round();
    return shifted / magnitude;
  }

  static double getNormalizedAngle(double angle) {
    while (angle < 0.0) angle += 360.0;

    return angle % 360.0;
  }

  static void getPosition(
      MPPointF center, double dist, double angle, MPPointF outputPoint) {
    outputPoint.x = (center.x + dist * cos((angle / 180 * pi)));
    outputPoint.y = (center.y + dist * sin((angle / 180 * pi)));
  }
}
