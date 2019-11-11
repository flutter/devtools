import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data/pie_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_pie_data_set.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/entry/pie_entry.dart';
import 'package:mp_chart/mp/core/enums/value_position.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/render/data_renderer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/pie_chart_painter.dart';

class PieChartRenderer extends DataRenderer {
  PieChartPainter _painter;

  /// paint for the hole in the center of the pie chart and the transparent
  /// circle
  Paint _holePaint;
  Paint _transparentCirclePaint;
  Paint _valueLinePaint;

  /// paint object for the text that can be displayed in the center of the
  /// chart
  TextPainter _centerTextPaint;

  /// paint object used for drwing the slice-text
  TextPainter _entryLabelsPaint;

//   StaticLayout _centerTextLayout;
  String _centerTextLastValue;
  Rect _centerTextLastBounds = Rect.zero;
  List<Rect> _rectBuffer = List()
    ..add(Rect.zero)
    ..add(Rect.zero)
    ..add(Rect.zero);

  /// Bitmap for drawing the center hole
//   WeakReference<Bitmap> mDrawBitmap;

//   Canvas mBitmapCanvas;

  PieChartRenderer(PieChartPainter chart, ChartAnimator animator,
      ViewPortHandler viewPortHandler,
      {TypeFace centerTextTypeface, TypeFace entryLabelTypeface})
      : super(animator, viewPortHandler) {
    _painter = chart;

    _holePaint = Paint()
      ..isAntiAlias = true
      ..color = ColorUtils.WHITE
      ..style = PaintingStyle.fill;

    _transparentCirclePaint = Paint()
      ..isAntiAlias = true
      ..color = Color.fromARGB(105, ColorUtils.WHITE.red,
          ColorUtils.WHITE.green, ColorUtils.WHITE.blue)
      ..style = PaintingStyle.fill;

    _centerTextPaint = PainterUtils.create(
        null, null, ColorUtils.BLACK, Utils.convertDpToPixel(12),
        fontFamily: centerTextTypeface?.fontFamily,
        fontWeight: centerTextTypeface?.fontWeight);

    valuePaint = PainterUtils.create(
        null, null, ColorUtils.WHITE, Utils.convertDpToPixel(9));

    _entryLabelsPaint = PainterUtils.create(
        null, null, ColorUtils.WHITE, Utils.convertDpToPixel(10),
        fontWeight: entryLabelTypeface?.fontWeight,
        fontFamily: entryLabelTypeface?.fontFamily);

    _valueLinePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
  }

  PieChartPainter get painter => _painter;

  Paint get holePaint => _holePaint;

  Paint get transparentCirclePaint => _transparentCirclePaint;

  TextPainter get centerTextPaint => _centerTextPaint;

  TextPainter get entryLabelsPaint => _entryLabelsPaint;

  set entryLabelsPaint(TextPainter value) {
    _entryLabelsPaint = value;
  }

  @override
  void initBuffers() {}

  @override
  void drawData(Canvas c) {
//    int width = viewPortHandler.getChartWidth().toInt();
//    int height = viewPortHandler.getChartHeight().toInt();

//    Bitmap drawBitmap = mDrawBitmap == null ? null : mDrawBitmap.get();

//    if (drawBitmap == null
//        || (drawBitmap.getWidth() != width)
//        || (drawBitmap.getHeight() != height)) {
//
//      if (width > 0 && height > 0) {
//        drawBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_4444);
//        mDrawBitmap =  WeakReference<>(drawBitmap);
//        mBitmapCanvas =  Canvas(drawBitmap);
//      } else
//        return;
//    }
//
//    drawBitmap.eraseColor(Color.TRANSPARENT);

    PieData pieData = _painter.getData();

    for (IPieDataSet set in pieData.dataSets) {
      if (set.isVisible() && set.getEntryCount() > 0) drawDataSet(c, set);
    }
  }

  Path mPathBuffer = Path();
  Rect mInnerRectBuffer = Rect.zero;

  double calculateMinimumRadiusForSpacedSlice(
      MPPointF center,
      double radius,
      double angle,
      double arcStartPointX,
      double arcStartPointY,
      double startAngle,
      double sweepAngle) {
    final double angleMiddle = startAngle + sweepAngle / 2.0;

    // Other point of the arc
    double arcEndPointX =
        center.x + radius * cos((startAngle + sweepAngle) * Utils.FDEG2RAD);
    double arcEndPointY =
        center.y + radius * sin((startAngle + sweepAngle) * Utils.FDEG2RAD);

    // Middle point on the arc
    double arcMidPointX = center.x + radius * cos(angleMiddle * Utils.FDEG2RAD);
    double arcMidPointY = center.y + radius * sin(angleMiddle * Utils.FDEG2RAD);

    // This is the base of the contained triangle
    double basePointsDistance = sqrt(pow(arcEndPointX - arcStartPointX, 2) +
        pow(arcEndPointY - arcStartPointY, 2));

    // After reducing space from both sides of the "slice",
    //   the angle of the contained triangle should stay the same.
    // So let's find out the height of that triangle.
    double containedTriangleHeight =
        (basePointsDistance / 2.0 * tan((180.0 - angle) / 2.0 * Utils.DEG2RAD));

    // Now we subtract that from the radius
    double spacedRadius = radius - containedTriangleHeight;

    // And now subtract the height of the arc that's between the triangle and the outer circle
    spacedRadius -= sqrt(
        pow(arcMidPointX - (arcEndPointX + arcStartPointX) / 2.0, 2) +
            pow(arcMidPointY - (arcEndPointY + arcStartPointY) / 2.0, 2));

    return spacedRadius;
  }

  /// Calculates the sliceSpace to use based on visible values and their size compared to the set sliceSpace.
  ///
  /// @param dataSet
  /// @return
  double getSliceSpace(IPieDataSet dataSet) {
    if (!dataSet.isAutomaticallyDisableSliceSpacingEnabled())
      return dataSet.getSliceSpace();

    double spaceSizeRatio =
        dataSet.getSliceSpace() / viewPortHandler.getSmallestContentExtension();
    double minValueRatio =
        dataSet.getYMin() / (_painter.getData() as PieData).getYValueSum() * 2;

    double sliceSpace =
        spaceSizeRatio > minValueRatio ? 0 : dataSet.getSliceSpace();

    return sliceSpace;
  }

  void drawDataSet(Canvas c, IPieDataSet dataSet) {
    double angle = 0;
    double rotationAngle = _painter.getRotationAngle();

    double phaseX = animator.getPhaseX();
    double phaseY = animator.getPhaseY();

    final Rect circleBox = _painter.getCircleBox();

    int entryCount = dataSet.getEntryCount();
    final List<double> drawAngles = _painter.getDrawAngles();
    final MPPointF center = _painter.getCenterCircleBox();
    final double radius = _painter.getRadius();
    bool drawInnerArc = _painter.isDrawHoleEnabled() &&
        !_painter.isDrawSlicesUnderHoleEnabled();
    final double userInnerRadius =
        drawInnerArc ? radius * (_painter.getHoleRadius() / 100.0) : 0.0;
    final double roundedRadius =
        (radius - (radius * _painter.getHoleRadius() / 100)) / 2;
    Rect roundedCircleBox = Rect.zero;
    final bool drawRoundedSlices =
        drawInnerArc && _painter.isDrawRoundedSlicesEnabled();

    int visibleAngleCount = 0;
    for (int j = 0; j < entryCount; j++) {
      // draw only if the value is greater than zero
      if ((dataSet.getEntryForIndex(j).getValue().abs() >
          Utils.FLOAT_EPSILON)) {
        visibleAngleCount++;
      }
    }

    final double sliceSpace =
        visibleAngleCount <= 1 ? 0.0 : getSliceSpace(dataSet);

    for (int j = 0; j < entryCount; j++) {
      double sliceAngle = drawAngles[j];
      double innerRadius = userInnerRadius;

      Entry e = dataSet.getEntryForIndex(j);

      // draw only if the value is greater than zero
      if (!(e.y.abs() > Utils.FLOAT_EPSILON)) {
        angle += sliceAngle * phaseX;
        continue;
      }

      // Don't draw if it's highlighted, unless the chart uses rounded slices
      if (_painter.needsHighlight(j) && !drawRoundedSlices) {
        angle += sliceAngle * phaseX;
        continue;
      }

      final bool accountForSliceSpacing =
          sliceSpace > 0.0 && sliceAngle <= 180.0;

      renderPaint..color = dataSet.getColor2(j);

      final double sliceSpaceAngleOuter =
          visibleAngleCount == 1 ? 0.0 : sliceSpace / (Utils.FDEG2RAD * radius);
      final double startAngleOuter =
          rotationAngle + (angle + sliceSpaceAngleOuter / 2.0) * phaseY;
      double sweepAngleOuter = (sliceAngle - sliceSpaceAngleOuter) * phaseY;
      if (sweepAngleOuter < 0.0) {
        sweepAngleOuter = 0.0;
      }

      mPathBuffer.reset();

      if (drawRoundedSlices) {
        double x = center.x +
            (radius - roundedRadius) * cos(startAngleOuter * Utils.FDEG2RAD);
        double y = center.y +
            (radius - roundedRadius) * sin(startAngleOuter * Utils.FDEG2RAD);
        roundedCircleBox = Rect.fromLTRB(x - roundedRadius, y - roundedRadius,
            x + roundedRadius, y + roundedRadius);
      }

      double arcStartPointX =
          center.x + radius * cos(startAngleOuter * Utils.FDEG2RAD);
      double arcStartPointY =
          center.y + radius * sin(startAngleOuter * Utils.FDEG2RAD);

      if (sweepAngleOuter >= 360.0 &&
          sweepAngleOuter % 360 <= Utils.FLOAT_EPSILON) {
        // Android is doing "mod 360"
        mPathBuffer.addOval(Rect.fromLTRB(center.x - radius, center.y - radius,
            center.x + radius, center.y + radius));
      } else {
        if (drawRoundedSlices) {
          mPathBuffer.arcTo(
              roundedCircleBox,
              (startAngleOuter + 180) * Utils.FDEG2RAD,
              -180 * Utils.FDEG2RAD,
              false);
        }

        mPathBuffer.arcTo(circleBox, startAngleOuter * Utils.FDEG2RAD,
            sweepAngleOuter * Utils.FDEG2RAD, false);
      }

      // API < 21 does not receive doubles in addArc, but a RectF
      mInnerRectBuffer = Rect.fromLTRB(
          center.x - innerRadius,
          center.y - innerRadius,
          center.x + innerRadius,
          center.y + innerRadius);

      if (drawInnerArc && (innerRadius > 0.0 || accountForSliceSpacing)) {
        if (accountForSliceSpacing) {
          double minSpacedRadius = calculateMinimumRadiusForSpacedSlice(
              center,
              radius,
              sliceAngle * phaseY,
              arcStartPointX,
              arcStartPointY,
              startAngleOuter,
              sweepAngleOuter);

          if (minSpacedRadius < 0.0) minSpacedRadius = -minSpacedRadius;

          innerRadius = max(innerRadius, minSpacedRadius);
        }

        final double sliceSpaceAngleInner =
            visibleAngleCount == 1 || innerRadius == 0.0
                ? 0.0
                : sliceSpace / (Utils.FDEG2RAD * innerRadius);
        final double startAngleInner =
            rotationAngle + (angle + sliceSpaceAngleInner / 2.0) * phaseY;
        double sweepAngleInner = (sliceAngle - sliceSpaceAngleInner) * phaseY;
        if (sweepAngleInner < 0.0) {
          sweepAngleInner = 0.0;
        }
        final double endAngleInner = startAngleInner + sweepAngleInner;

        if (sweepAngleOuter >= 360.0 &&
            sweepAngleOuter % 360 <= Utils.FLOAT_EPSILON) {
          // Android is doing "mod 360"
          mPathBuffer.addOval(Rect.fromLTRB(
              center.x - innerRadius,
              center.y - innerRadius,
              center.x + innerRadius,
              center.y + innerRadius));
        } else {
          if (drawRoundedSlices) {
            double x = center.x +
                (radius - roundedRadius) * cos(endAngleInner * Utils.FDEG2RAD);
            double y = center.y +
                (radius - roundedRadius) * sin(endAngleInner * Utils.FDEG2RAD);
            roundedCircleBox = Rect.fromLTRB(x - roundedRadius,
                y - roundedRadius, x + roundedRadius, y + roundedRadius);
            mPathBuffer.arcTo(roundedCircleBox, endAngleInner * Utils.FDEG2RAD,
                180 * Utils.FDEG2RAD, false);
          } else {
//            mPathBuffer.lineTo(
//                center.x + innerRadius * cos(endAngleInner * Utils.FDEG2RAD),
//                center.y + innerRadius * sin(endAngleInner * Utils.FDEG2RAD));
            double angleMiddle = startAngleOuter + sweepAngleOuter / 2.0;
            double sliceSpaceOffset = calculateMinimumRadiusForSpacedSlice(
                center,
                radius,
                sliceAngle * phaseY,
                arcStartPointX,
                arcStartPointY,
                startAngleOuter,
                sweepAngleOuter);
            mPathBuffer.lineTo(
                center.x + sliceSpaceOffset * cos(angleMiddle * Utils.FDEG2RAD),
                center.y +
                    sliceSpaceOffset * sin(angleMiddle * Utils.FDEG2RAD));
          }

          mPathBuffer.arcTo(mInnerRectBuffer, endAngleInner * Utils.FDEG2RAD,
              -sweepAngleInner * Utils.FDEG2RAD, false);
        }
      } else {
        if (sweepAngleOuter % 360 > Utils.FLOAT_EPSILON) {
          if (accountForSliceSpacing) {
            double angleMiddle = startAngleOuter + sweepAngleOuter / 2.0;

            double sliceSpaceOffset = calculateMinimumRadiusForSpacedSlice(
                center,
                radius,
                sliceAngle * phaseY,
                arcStartPointX,
                arcStartPointY,
                startAngleOuter,
                sweepAngleOuter);

            double arcEndPointX =
                center.x + sliceSpaceOffset * cos(angleMiddle * Utils.FDEG2RAD);
            double arcEndPointY =
                center.y + sliceSpaceOffset * sin(angleMiddle * Utils.FDEG2RAD);

            mPathBuffer.lineTo(arcEndPointX, arcEndPointY);
          } else {
            mPathBuffer.lineTo(center.x, center.y);
          }
        }
      }

      mPathBuffer.close();

      c.drawPath(mPathBuffer, renderPaint);

      angle += sliceAngle * phaseX;
    }

    renderPaint..color = ColorUtils.WHITE;
    c.drawCircle(
        Offset(center.x, center.y), mInnerRectBuffer.width / 2, renderPaint);

    MPPointF.recycleInstance(center);
  }

  @override
  void drawValues(Canvas c) {
    MPPointF center = _painter.getCenterCircleBox();

    // get whole the radius
    double radius = _painter.getRadius();
    double rotationAngle = _painter.getRotationAngle();
    List<double> drawAngles = _painter.getDrawAngles();
    List<double> absoluteAngles = _painter.getAbsoluteAngles();

    double phaseX = animator.getPhaseX();
    double phaseY = animator.getPhaseY();

    final double roundedRadius =
        (radius - (radius * _painter.getHoleRadius() / 100)) / 2;
    final double holeRadiusPercent = _painter.getHoleRadius() / 100.0;
    double labelRadiusOffset = radius / 10 * 3.6;

    if (_painter.isDrawHoleEnabled()) {
      labelRadiusOffset = (radius - (radius * holeRadiusPercent)) / 2;

      if (!_painter.isDrawSlicesUnderHoleEnabled() &&
          _painter.isDrawRoundedSlicesEnabled()) {
        // Add curved circle slice and spacing to rotation angle, so that it sits nicely inside
        rotationAngle += roundedRadius * 360 / (pi * 2 * radius);
      }
    }

    final double labelRadius = radius - labelRadiusOffset;

    PieData data = _painter.getData();
    List<IPieDataSet> dataSets = data.dataSets;

    double yValueSum = data.getYValueSum();

    bool drawEntryLabels = _painter.isDrawEntryLabelsEnabled();

    double angle;
    int xIndex = 0;

    c.save();

    double offset = Utils.convertDpToPixel(5.0);

    for (int i = 0; i < dataSets.length; i++) {
      IPieDataSet dataSet = dataSets[i];

      final bool drawValues = dataSet.isDrawValuesEnabled();

      if (!drawValues && !drawEntryLabels) continue;

      final ValuePosition xValuePosition = dataSet.getXValuePosition();
      final ValuePosition yValuePosition = dataSet.getYValuePosition();

      // apply the text-styling defined by the DataSet
      applyValueTextStyle(dataSet);

      double lineHeight =
          Utils.calcTextHeight(valuePaint, "Q") + Utils.convertDpToPixel(4);

      ValueFormatter formatter = dataSet.getValueFormatter();

      int entryCount = dataSet.getEntryCount();

      _valueLinePaint
        ..color = dataSet.getValueLineColor()
        ..strokeWidth = Utils.convertDpToPixel(dataSet.getValueLineWidth());

      final double sliceSpace = getSliceSpace(dataSet);

      MPPointF iconsOffset = MPPointF.getInstance3(dataSet.getIconsOffset());
      iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
      iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

      for (int j = 0; j < entryCount; j++) {
        PieEntry entry = dataSet.getEntryForIndex(j);

        if (xIndex == 0)
          angle = 0.0;
        else
          angle = absoluteAngles[xIndex - 1] * phaseX;

        final double sliceAngle = drawAngles[xIndex];
        final double sliceSpaceMiddleAngle =
            sliceSpace / (Utils.FDEG2RAD * labelRadius);

        // offset needed to center the drawn text in the slice
        final double angleOffset =
            (sliceAngle - sliceSpaceMiddleAngle / 2.0) / 2.0;

        angle = angle + angleOffset;

        final double transformedAngle = rotationAngle + angle * phaseY;

        double value = _painter.isUsePercentValuesEnabled()
            ? entry.y / yValueSum * 100
            : entry.y;
        String formattedValue = formatter.getPieLabel(value, entry);
        String entryLabel = entry.label;

        final double sliceXBase = cos(transformedAngle * Utils.FDEG2RAD);
        final double sliceYBase = sin(transformedAngle * Utils.FDEG2RAD);

        final bool drawXOutside =
            drawEntryLabels && xValuePosition == ValuePosition.OUTSIDE_SLICE;
        final bool drawYOutside =
            drawValues && yValuePosition == ValuePosition.OUTSIDE_SLICE;
        final bool drawXInside =
            drawEntryLabels && xValuePosition == ValuePosition.INSIDE_SLICE;
        final bool drawYInside =
            drawValues && yValuePosition == ValuePosition.INSIDE_SLICE;

        if (drawXOutside || drawYOutside) {
          final double valueLineLength1 = dataSet.getValueLinePart1Length();
          final double valueLineLength2 = dataSet.getValueLinePart2Length();
          final double valueLinePart1OffsetPercentage =
              dataSet.getValueLinePart1OffsetPercentage() / 100.0;

          double pt2x, pt2y;
          double labelPtx, labelPty;

          double line1Radius;

          if (_painter.isDrawHoleEnabled())
            line1Radius = (radius - (radius * holeRadiusPercent)) *
                    valueLinePart1OffsetPercentage +
                (radius * holeRadiusPercent);
          else
            line1Radius = radius * valueLinePart1OffsetPercentage;

          final double polyline2Width = dataSet.isValueLineVariableLength()
              ? labelRadius *
                  valueLineLength2 *
                  sin(transformedAngle * Utils.FDEG2RAD).abs()
              : labelRadius * valueLineLength2;

          final double pt0x = line1Radius * sliceXBase + center.x;
          final double pt0y = line1Radius * sliceYBase + center.y;

          final double pt1x =
              labelRadius * (1 + valueLineLength1) * sliceXBase + center.x;
          final double pt1y =
              labelRadius * (1 + valueLineLength1) * sliceYBase + center.y;

          if (transformedAngle % 360.0 >= 90.0 &&
              transformedAngle % 360.0 <= 270.0) {
            pt2x = pt1x - polyline2Width;
            pt2y = pt1y;

            labelPtx = pt2x - offset;
            labelPty = pt2y;
          } else {
            pt2x = pt1x + polyline2Width;
            pt2y = pt1y;

            labelPtx = pt2x + offset;
            labelPty = pt2y;
          }

          if (dataSet.getValueLineColor() != ColorUtils.COLOR_NONE) {
            if (dataSet.isUsingSliceColorAsValueLineColor()) {
              _valueLinePaint..color = dataSet.getColor2(j);
            }

            c.drawLine(Offset(pt0x, pt0y), Offset(pt1x, pt1y), _valueLinePaint);
            c.drawLine(Offset(pt1x, pt1y), Offset(pt2x, pt2y), _valueLinePaint);
          }

          // draw everything, depending on settings
          if (drawXOutside && drawYOutside) {
            drawValue(c, formattedValue, labelPtx, labelPty,
                dataSet.getValueTextColor2(j));

            if (j < data.getEntryCount() && entryLabel != null) {
              drawEntryLabel(c, entryLabel, labelPtx, labelPty + lineHeight);
            }
          } else if (drawXOutside) {
            if (j < data.getEntryCount() && entryLabel != null) {
              drawEntryLabel(
                  c, entryLabel, labelPtx, labelPty + lineHeight / 2.0);
            }
          } else if (drawYOutside) {
            drawValueByHeight(
                c,
                formattedValue,
                labelPtx,
                labelPty + lineHeight / 2.0,
                dataSet.getValueTextColor2(j),
                false);
          }
        }

        if (drawXInside || drawYInside) {
          // calculate the text position
          double x = labelRadius * sliceXBase + center.x;
          double y = labelRadius * sliceYBase + center.y;

          // draw everything, depending on settings
          if (drawXInside && drawYInside) {
            drawValueByHeight(
                c, formattedValue, x, y, dataSet.getValueTextColor2(j), true);

            if (j < data.getEntryCount() && entryLabel != null) {
              drawEntryLabel(c, entryLabel, x, y + lineHeight);
            }
          } else if (drawXInside) {
            if (j < data.getEntryCount() && entryLabel != null) {
              drawEntryLabel(c, entryLabel, x, y + lineHeight / 2);
            }
          } else if (drawYInside) {
            drawValue(c, formattedValue, x, y + lineHeight / 2,
                dataSet.getValueTextColor2(j));
          }
        }

        if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
          double x = (labelRadius + iconsOffset.y) * sliceXBase + center.x;
          double y = (labelRadius + iconsOffset.y) * sliceYBase + center.y;
          y += iconsOffset.x;

          CanvasUtils.drawImage(
              c, Offset(x, y), entry.mIcon, Size(15, 15), drawPaint);
        }

        xIndex++;
      }

      MPPointF.recycleInstance(iconsOffset);
    }
    MPPointF.recycleInstance(center);
    c.restore();
  }

  void drawValueByHeight(Canvas c, String valueText, double x, double y,
      Color color, bool useHeight) {
    valuePaint = PainterUtils.create(
        valuePaint,
        valueText,
        color,
        valuePaint.text.style.fontSize == null
            ? Utils.convertDpToPixel(13)
            : valuePaint.text.style.fontSize);
    valuePaint.layout();
    valuePaint.paint(
        c,
        Offset(
            x - valuePaint.width / 2, useHeight ? y - valuePaint.height : y));
  }

  @override
  void drawValue(Canvas c, String valueText, double x, double y, Color color) {
    valuePaint = PainterUtils.create(
        valuePaint,
        valueText,
        color,
        valuePaint.text.style.fontSize == null
            ? Utils.convertDpToPixel(13)
            : valuePaint.text.style.fontSize);
    valuePaint.layout();
    valuePaint.paint(
        c, Offset(x - valuePaint.width / 2, y - valuePaint.height));
  }

  /// Draws an entry label at the specified position.
  ///
  /// @param c
  /// @param label
  /// @param x
  /// @param y
  void drawEntryLabel(Canvas c, String label, double x, double y) {
    _entryLabelsPaint = PainterUtils.create(
        _entryLabelsPaint, label, ColorUtils.WHITE, Utils.convertDpToPixel(10));
    _entryLabelsPaint.layout();
    _entryLabelsPaint.paint(c,
        Offset(x - _entryLabelsPaint.width / 2, y - _entryLabelsPaint.height));
  }

  @override
  void drawExtras(Canvas c) {
    drawHole(c);
//    c.drawBitmap(mDrawBitmap.get(), 0, 0, null);
    drawCenterText(c);
  }

  Path mHoleCirclePath = Path();

  /// draws the hole in the center of the chart and the transparent circle /
  /// hole
  void drawHole(Canvas c) {
//    if (_painter.isDrawHoleEnabled() && mBitmapCanvas != null) {
    if (_painter.isDrawHoleEnabled()) {
      double radius = _painter.getRadius();
      double holeRadius = radius * (_painter.getHoleRadius() / 100);
      MPPointF center = _painter.getCenterCircleBox();

//      if (_holePaint.color.alpha > 0) {
//        // draw the hole-circle
//        mBitmapCanvas.drawCircle(
//            center.x, center.y,
//            holeRadius, _holePaint);
//      }

      // only draw the circle if it can be seen (not covered by the hole)
      if (_transparentCirclePaint.color.alpha > 0 &&
          _painter.getTransparentCircleRadius() > _painter.getHoleRadius()) {
        int alpha = _transparentCirclePaint.color.alpha;
        double secondHoleRadius =
            radius * (_painter.getTransparentCircleRadius() / 100);

        _transparentCirclePaint.color = Color.fromARGB(
            (alpha * animator.getPhaseX() * animator.getPhaseY()).toInt(),
            _transparentCirclePaint.color.red,
            _transparentCirclePaint.color.green,
            _transparentCirclePaint.color.blue);

        // draw the transparent-circle
        mHoleCirclePath.reset();
        mHoleCirclePath.addOval(Rect.fromLTRB(
            center.x - secondHoleRadius,
            center.y - secondHoleRadius,
            center.x + secondHoleRadius,
            center.y + secondHoleRadius));
        mHoleCirclePath.addOval(Rect.fromLTRB(
            center.x - holeRadius,
            center.y - holeRadius,
            center.x + holeRadius,
            center.y + holeRadius));

//        mBitmapCanvas.drawPath(mHoleCirclePath, _transparentCirclePaint);
        c.drawPath(mHoleCirclePath, _transparentCirclePaint);

        // reset alpha
        _transparentCirclePaint.color = Color.fromARGB(
            alpha,
            _transparentCirclePaint.color.red,
            _transparentCirclePaint.color.green,
            _transparentCirclePaint.color.blue);
      }
      MPPointF.recycleInstance(center);
    }
  }

  Path mDrawCenterTextPathBuffer = Path();

  /// draws the description text in the center of the pie chart makes most
  /// sense when center-hole is enabled
  void drawCenterText(Canvas c) {
    String centerText = _painter.getCenterText();

    if (_painter.isDrawCenterTextEnabled() && centerText != null) {
      MPPointF center = _painter.getCenterCircleBox();
      MPPointF offset = _painter.getCenterTextOffset();

      double x = center.x + offset.x;
      double y = center.y + offset.y;

      double innerRadius = _painter.isDrawHoleEnabled() &&
              !_painter.isDrawSlicesUnderHoleEnabled()
          ? _painter.getRadius() * (_painter.getHoleRadius() / 100)
          : _painter.getRadius();

      _rectBuffer[0] = Rect.fromLTRB(
          x - innerRadius, y - innerRadius, x + innerRadius, y + innerRadius);
//      Rect holeRect = _rectBuffer[0];
      _rectBuffer[1] = Rect.fromLTRB(
          x - innerRadius, y - innerRadius, x + innerRadius, y + innerRadius);
//      Rect boundingRect = _rectBuffer[1];

      double radiusPercent = _painter.getCenterTextRadiusPercent() / 100;
      if (radiusPercent > 0.0) {
        var dx =
            (_rectBuffer[1].width - _rectBuffer[1].width * radiusPercent) / 2.0;
        var dy =
            (_rectBuffer[1].height - _rectBuffer[1].height * radiusPercent) /
                2.0;
        _rectBuffer[1] = Rect.fromLTRB(
            _rectBuffer[1].left + dx,
            _rectBuffer[1].top + dx,
            _rectBuffer[1].right - dy,
            _rectBuffer[1].bottom - dy);
      }

//      if (!(centerText == _centerTextLastValue) ||
//          !(_rectBuffer[1] == _centerTextLastBounds)) {
//        // Next time we won't recalculate StaticLayout...
//        _centerTextLastBounds = Rect.fromLTRB(_rectBuffer[1].left,
//            _rectBuffer[1].top, _rectBuffer[1].right, _rectBuffer[1].bottom);
//        _centerTextLastValue = centerText;
//      }

      c.save();

      _centerTextPaint = PainterUtils.create(_centerTextPaint, centerText,
          ColorUtils.BLACK, Utils.convertDpToPixel(12));
      _centerTextPaint.layout();
      _centerTextPaint.paint(
          c,
          Offset(
              _rectBuffer[1].left +
                  _rectBuffer[1].width / 2 -
                  _centerTextPaint.width / 2,
              _rectBuffer[1].top +
                  _rectBuffer[1].height / 2 -
                  _centerTextPaint.height / 2));

      c.restore();

      MPPointF.recycleInstance(center);
      MPPointF.recycleInstance(offset);
    }
  }

  Rect _drawHighlightedRectF = Rect.zero;

  @override
  void drawHighlighted(Canvas c, List<Highlight> indices) {
    final bool drawInnerArc = _painter.isDrawHoleEnabled() &&
        !_painter.isDrawSlicesUnderHoleEnabled();
    if (drawInnerArc && _painter.isDrawRoundedSlicesEnabled()) return;

    double phaseX = animator.getPhaseX();
    double phaseY = animator.getPhaseY();

    double angle;
    double rotationAngle = _painter.getRotationAngle();

    List<double> drawAngles = _painter.getDrawAngles();
    List<double> absoluteAngles = _painter.getAbsoluteAngles();
    final MPPointF center = _painter.getCenterCircleBox();
    final double radius = _painter.getRadius();
    final double userInnerRadius =
        drawInnerArc ? radius * (_painter.getHoleRadius() / 100.0) : 0.0;

//    final Rect highlightedCircleBox = _drawHighlightedRectF;
    _drawHighlightedRectF = Rect.zero;

    for (int i = 0; i < indices.length; i++) {
      // get the index to highlight
      int index = indices[i].x.toInt();

      if (index >= drawAngles.length) continue;

      IPieDataSet set =
          _painter.getData().getDataSetByIndex(indices[i].dataSetIndex);

      if (set == null || !set.isHighlightEnabled()) continue;

      final int entryCount = set.getEntryCount();
      int visibleAngleCount = 0;
      for (int j = 0; j < entryCount; j++) {
        // draw only if the value is greater than zero
        if ((set.getEntryForIndex(j).y.abs() > Utils.FLOAT_EPSILON)) {
          visibleAngleCount++;
        }
      }

      if (index == 0)
        angle = 0.0;
      else
        angle = absoluteAngles[index - 1] * phaseX;

      final double sliceSpace =
          visibleAngleCount <= 1 ? 0.0 : set.getSliceSpace();

      double sliceAngle = drawAngles[index];
      double innerRadius = userInnerRadius;

      double shift = set.getSelectionShift();
      final double highlightedRadius = radius + shift;
      _drawHighlightedRectF = Rect.fromLTRB(
          _painter.getCircleBox().left - shift,
          _painter.getCircleBox().top - shift,
          _painter.getCircleBox().right + shift,
          _painter.getCircleBox().bottom + shift);

      final bool accountForSliceSpacing =
          sliceSpace > 0.0 && sliceAngle <= 180.0;

      renderPaint.color = set.getColor2(index);

      final double sliceSpaceAngleOuter =
          visibleAngleCount == 1 ? 0.0 : sliceSpace / (Utils.FDEG2RAD * radius);

      final double sliceSpaceAngleShifted = visibleAngleCount == 1
          ? 0.0
          : sliceSpace / (Utils.FDEG2RAD * highlightedRadius);

      final double startAngleOuter =
          rotationAngle + (angle + sliceSpaceAngleOuter / 2.0) * phaseY;
      double sweepAngleOuter = (sliceAngle - sliceSpaceAngleOuter) * phaseY;
      if (sweepAngleOuter < 0.0) {
        sweepAngleOuter = 0.0;
      }

      final double startAngleShifted =
          rotationAngle + (angle + sliceSpaceAngleShifted / 2.0) * phaseY;
      double sweepAngleShifted = (sliceAngle - sliceSpaceAngleShifted) * phaseY;
      if (sweepAngleShifted < 0.0) {
        sweepAngleShifted = 0.0;
      }

      mPathBuffer.reset();

      if (sweepAngleOuter >= 360.0 &&
          sweepAngleOuter % 360 <= Utils.FLOAT_EPSILON) {
        // Android is doing "mod 360"
        mPathBuffer.addOval(Rect.fromLTRB(
            center.x - highlightedRadius,
            center.y - highlightedRadius,
            center.x + highlightedRadius,
            center.y + highlightedRadius));
      } else {
        mPathBuffer.moveTo(
            center.x +
                highlightedRadius * cos(startAngleShifted * Utils.FDEG2RAD),
            center.y +
                highlightedRadius * sin(startAngleShifted * Utils.FDEG2RAD));

        mPathBuffer.arcTo(
            _drawHighlightedRectF,
            startAngleShifted * Utils.FDEG2RAD,
            sweepAngleShifted * Utils.FDEG2RAD,
            false);
      }

      double sliceSpaceRadius = 0.0;
      if (accountForSliceSpacing) {
        sliceSpaceRadius = calculateMinimumRadiusForSpacedSlice(
            center,
            radius,
            sliceAngle * phaseY,
            center.x + radius * cos(startAngleOuter * Utils.FDEG2RAD),
            center.y + radius * sin(startAngleOuter * Utils.FDEG2RAD),
            startAngleOuter,
            sweepAngleOuter);
      }

      // API < 21 does not receive doubles in addArc, but a RectF
      mInnerRectBuffer = Rect.fromLTRB(
          center.x - innerRadius,
          center.y - innerRadius,
          center.x + innerRadius,
          center.y + innerRadius);

      if (drawInnerArc && (innerRadius > 0.0 || accountForSliceSpacing)) {
        if (accountForSliceSpacing) {
          double minSpacedRadius = sliceSpaceRadius;

          if (minSpacedRadius < 0.0) minSpacedRadius = -minSpacedRadius;

          innerRadius = max(innerRadius, minSpacedRadius);
        }

        final double sliceSpaceAngleInner =
            visibleAngleCount == 1 || innerRadius == 0.0
                ? 0.0
                : sliceSpace / (Utils.FDEG2RAD * innerRadius);
        final double startAngleInner =
            rotationAngle + (angle + sliceSpaceAngleInner / 2.0) * phaseY;
        double sweepAngleInner = (sliceAngle - sliceSpaceAngleInner) * phaseY;
        if (sweepAngleInner < 0.0) {
          sweepAngleInner = 0.0;
        }
        final double endAngleInner = startAngleInner + sweepAngleInner;

        if (sweepAngleOuter >= 360.0 &&
            sweepAngleOuter % 360 <= Utils.FLOAT_EPSILON) {
          // Android is doing "mod 360"
          mPathBuffer.addOval(Rect.fromLTRB(
              center.x - innerRadius,
              center.y - innerRadius,
              center.x + innerRadius,
              center.y + innerRadius));
        } else {
          final double angleMiddle = startAngleOuter + sweepAngleOuter / 2.0;

          final double arcEndPointX =
              center.x + sliceSpaceRadius * cos(angleMiddle * Utils.FDEG2RAD);
          final double arcEndPointY =
              center.y + sliceSpaceRadius * sin(angleMiddle * Utils.FDEG2RAD);
          mPathBuffer.lineTo(arcEndPointX, arcEndPointY);
//          mPathBuffer.lineTo(
//              center.x + innerRadius * cos(endAngleInner * Utils.FDEG2RAD),
//              center.y + innerRadius * sin(endAngleInner * Utils.FDEG2RAD));

          mPathBuffer.arcTo(mInnerRectBuffer, endAngleInner * Utils.FDEG2RAD,
              -sweepAngleInner * Utils.FDEG2RAD, false);
        }
      } else {
        if (sweepAngleOuter % 360 > Utils.FLOAT_EPSILON) {
          if (accountForSliceSpacing) {
            final double angleMiddle = startAngleOuter + sweepAngleOuter / 2.0;

            final double arcEndPointX =
                center.x + sliceSpaceRadius * cos(angleMiddle * Utils.FDEG2RAD);
            final double arcEndPointY =
                center.y + sliceSpaceRadius * sin(angleMiddle * Utils.FDEG2RAD);

            mPathBuffer.lineTo(arcEndPointX, arcEndPointY);
          } else {
            mPathBuffer.lineTo(center.x, center.y);
          }
        }
      }

      mPathBuffer.close();

//      mBitmapCanvas.drawPath(mPathBuffer, renderPaint);
      c.drawPath(mPathBuffer, renderPaint);
      renderPaint..color = ColorUtils.WHITE;
      c.drawOval(mInnerRectBuffer, renderPaint);
    }

    MPPointF.recycleInstance(center);
  }

  /// This gives all pie-slices a rounded edge.
  ///
  /// @param c
  void drawRoundedSlices(Canvas c) {
    if (!_painter.isDrawRoundedSlicesEnabled()) return;

    IPieDataSet dataSet = (_painter.getData() as PieData).getDataSet();

    if (!dataSet.isVisible()) return;

    double phaseX = animator.getPhaseX();
    double phaseY = animator.getPhaseY();

    MPPointF center = _painter.getCenterCircleBox();
    double r = _painter.getRadius();

    // calculate the radius of the "slice-circle"
    double circleRadius = (r - (r * _painter.getHoleRadius() / 100)) / 2;

    List<double> drawAngles = _painter.getDrawAngles();
    double angle = _painter.getRotationAngle();

    for (int j = 0; j < dataSet.getEntryCount(); j++) {
      double sliceAngle = drawAngles[j];

      Entry e = dataSet.getEntryForIndex(j);

      // draw only if the value is greater than zero
      if ((e.y.abs() > Utils.FLOAT_EPSILON)) {
        double x = ((r - circleRadius) *
                cos((angle + sliceAngle) * phaseY / 180 * pi) +
            center.x);
        double y = ((r - circleRadius) *
                sin((angle + sliceAngle) * phaseY / 180 * pi) +
            center.y);

        renderPaint.color = dataSet.getColor2(j);
//        mBitmapCanvas.drawCircle(x, y, circleRadius, renderPaint);
        c.drawCircle(Offset(x, y), circleRadius, renderPaint);
      }

      angle += sliceAngle * phaseX;
    }
    MPPointF.recycleInstance(center);
  }

//  /**
//   * Releases the drawing bitmap. This should be called when {@link LineChart#onDetachedFromWindow()}.
//   */
//   void releaseBitmap() {
//    if (mBitmapCanvas != null) {
//      mBitmapCanvas.setBitmap(null);
//      mBitmapCanvas = null;
//    }
//    if (mDrawBitmap != null) {
//      Bitmap drawBitmap = mDrawBitmap.get();
//      if (drawBitmap != null) {
//        drawBitmap.recycle();
//      }
//      mDrawBitmap.clear();
//      mDrawBitmap = null;
//    }
//  }

  void setHoleColor(Color color) {
    holePaint.color = color;
  }

  /// Sets the color the transparent-circle should have.
  ///
  /// @param color
  void setTransparentCircleColor(Color color) {
    Paint p = transparentCirclePaint;
    p.color = Color.fromARGB(p.color?.alpha == null ? 255 : p.color?.alpha,
        color.red, color.green, color.blue);
  }

  /// Sets the amount of transparency the transparent circle should have 0 = fully transparent,
  /// 255 = fully opaque.
  /// Default value is 100.
  ///
  /// @param alpha 0-255
  void setTransparentCircleAlpha(int alpha) {
    Color color = transparentCirclePaint.color;
    transparentCirclePaint.color =
        Color.fromARGB(alpha, color.red, color.green, color.blue);
  }

  /// Sets the color the entry labels are drawn with.
  ///
  /// @param color
  void setEntryLabelColor(Color color) {
    entryLabelsPaint = PainterUtils.create(entryLabelsPaint, null, color, null);
  }

  /// Sets the size of the entry labels in dp. Default: 13dp
  ///
  /// @param size
  void setEntryLabelTextSize(double size) {
    var style = entryLabelsPaint.text.style;
    entryLabelsPaint = PainterUtils.create(
        entryLabelsPaint,
        null,
        style?.color == null ? ColorUtils.WHITE : style?.color,
        Utils.convertDpToPixel(size));
  }
}
