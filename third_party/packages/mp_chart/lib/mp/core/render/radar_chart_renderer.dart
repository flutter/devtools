import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data/radar_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_radar_data_set.dart';
import 'package:mp_chart/mp/core/entry/radar_entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/render/line_radar_renderer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/radar_chart_painter.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class RadarChartRenderer extends LineRadarRenderer {
  RadarChartPainter _painter;

  /// paint for drawing the web
  Paint _webPaint;
  Paint _highlightCirclePaint;

  RadarChartRenderer(RadarChartPainter chart, Animator animator,
      ViewPortHandler viewPortHandler)
      : super(animator, viewPortHandler) {
    _painter = chart;

    _highlightCirclePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = Utils.convertDpToPixel(2)
      ..color = Color.fromARGB(255, 255, 187, 115);

    _webPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    _highlightCirclePaint = Paint()
      ..isAntiAlias = true
      ..style;
  }

  Paint get webPaint => _webPaint;

  RadarChartPainter get painter => _painter;

  @override
  void initBuffers() {}

  @override
  void drawData(Canvas c) {
    RadarData radarData = _painter.getData();

    int mostEntries = radarData.getMaxEntryCountSet().getEntryCount();

    for (IRadarDataSet set in radarData.dataSets) {
      if (set.isVisible()) {
        drawDataSet(c, set, mostEntries);
      }
    }
  }

  Path mDrawDataSetSurfacePathBuffer = new Path();

  /// Draws the RadarDataSet
  ///
  /// @param c
  /// @param dataSet
  /// @param mostEntries the entry count of the dataset with the most entries
  void drawDataSet(Canvas c, IRadarDataSet dataSet, int mostEntries) {
    double phaseX = animator.getPhaseX();
    double phaseY = animator.getPhaseY();

    double sliceangle = _painter.getSliceAngle();

    // calculate the factor that is needed for transforming the value to
    // pixels
    double factor = _painter.getFactor();

    MPPointF center = _painter.getCenterOffsets();
    MPPointF pOut = MPPointF.getInstance1(0, 0);
    Path surface = mDrawDataSetSurfacePathBuffer;
    surface.reset();

    bool hasMovedToPoint = false;

    for (int j = 0; j < dataSet.getEntryCount(); j++) {
      renderPaint.color = dataSet.getColor2(j);

      RadarEntry e = dataSet.getEntryForIndex(j);

      Utils.getPosition(
          center,
          (e.y - _painter.getYChartMin()) * factor * phaseY,
          sliceangle * j * phaseX + _painter.getRotationAngle(),
          pOut);

      if (pOut.x.isNaN) continue;

      if (!hasMovedToPoint) {
        surface.moveTo(pOut.x, pOut.y);
        hasMovedToPoint = true;
      } else
        surface.lineTo(pOut.x, pOut.y);
    }

    if (dataSet.getEntryCount() > mostEntries) {
      // if this is not the largest set, draw a line to the center before closing
      surface.lineTo(center.x, center.y);
    }

    surface.close();

    if (dataSet.isDrawFilledEnabled()) {
//      final Drawable drawable = dataSet.getFillDrawable();
//      if (drawable != null) {
//
//        drawFilledPath(c, surface, drawable);
//      } else {

      drawFilledPath2(
          c, surface, dataSet.getFillColor().value, dataSet.getFillAlpha());
//      }
    }

    renderPaint
      ..strokeWidth = dataSet.getLineWidth()
      ..style = PaintingStyle.stroke;

    // draw the line (only if filled is disabled or alpha is below 255)
    if (!dataSet.isDrawFilledEnabled() || dataSet.getFillAlpha() < 255)
      c.drawPath(surface, renderPaint);

    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
  }

  @override
  void drawValues(Canvas c) {
    double phaseX = animator.getPhaseX();
    double phaseY = animator.getPhaseY();

    double sliceangle = _painter.getSliceAngle();

    // calculate the factor that is needed for transforming the value to
    // pixels
    double factor = _painter.getFactor();

    MPPointF center = _painter.getCenterOffsets();
    MPPointF pOut = MPPointF.getInstance1(0, 0);
    MPPointF pIcon = MPPointF.getInstance1(0, 0);

    double yoffset = Utils.convertDpToPixel(5);

    for (int i = 0; i < _painter.getData().getDataSetCount(); i++) {
      IRadarDataSet dataSet = _painter.getData().getDataSetByIndex(i);

      if (!shouldDrawValues(dataSet)) continue;

      // apply the text-styling defined by the DataSet
      applyValueTextStyle(dataSet);

      ValueFormatter formatter = dataSet.getValueFormatter();

      MPPointF iconsOffset = MPPointF.getInstance3(dataSet.getIconsOffset());
      iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
      iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

      for (int j = 0; j < dataSet.getEntryCount(); j++) {
        RadarEntry entry = dataSet.getEntryForIndex(j);

        Utils.getPosition(
            center,
            (entry.y - _painter.getYChartMin()) * factor * phaseY,
            sliceangle * j * phaseX + _painter.getRotationAngle(),
            pOut);

        if (dataSet.isDrawValuesEnabled()) {
          drawValue(c, formatter.getRadarLabel(entry), pOut.x, pOut.y - yoffset,
              dataSet.getValueTextColor2(j));
        }

        if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
          Utils.getPosition(center, entry.y * factor * phaseY + iconsOffset.y,
              sliceangle * j * phaseX + _painter.getRotationAngle(), pIcon);

          //noinspection SuspiciousNameCombination
          pIcon.y += iconsOffset.x;

          CanvasUtils.drawImage(c, Offset(pIcon.x, pIcon.y), entry.mIcon,
              Size(15, 15), drawPaint);
        }
      }

      MPPointF.recycleInstance(iconsOffset);
    }

    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
    MPPointF.recycleInstance(pIcon);
  }

  @override
  void drawValue(Canvas c, String valueText, double x, double y, Color color) {
    valuePaint = PainterUtils.create(
        valuePaint,
        valueText,
        color,
        valuePaint.text.style.fontSize == null
            ? Utils.convertDpToPixel(9)
            : valuePaint.text.style.fontSize);
    valuePaint.layout();
    valuePaint.paint(
        c, Offset(x - valuePaint.width / 2, y - valuePaint.height));
  }

  @override
  void drawExtras(Canvas c) {
    drawWeb(c);
  }

  void drawWeb(Canvas c) {
    double sliceangle = _painter.getSliceAngle();

    // calculate the factor that is needed for transforming the value to
    // pixels
    double factor = _painter.getFactor();
    double rotationangle = _painter.getRotationAngle();

    MPPointF center = _painter.getCenterOffsets();

    // draw the web lines that come from the center
    var color = _painter.webColor;
    _webPaint
      ..strokeWidth = _painter.webLineWidth
      ..color =
          Color.fromARGB(_painter.webAlpha, color.red, color.green, color.blue);

    final int xIncrements = 1 + _painter.skipWebLineCount;
    int maxEntryCount =
        _painter.getData().getMaxEntryCountSet().getEntryCount();

    MPPointF p = MPPointF.getInstance1(0, 0);
    for (int i = 0; i < maxEntryCount; i += xIncrements) {
      Utils.getPosition(center, _painter.yAxis.axisRange * factor,
          sliceangle * i + rotationangle, p);

      c.drawLine(Offset(center.x, center.y), Offset(p.x, p.y), _webPaint);
    }
    MPPointF.recycleInstance(p);

    // draw the inner-web
    color = _painter.webColorInner;
    _webPaint
      ..strokeWidth = _painter.innerWebLineWidth
      ..color =
          Color.fromARGB(_painter.webAlpha, color.red, color.green, color.blue);

    int labelCount = _painter.yAxis.entryCount;

    MPPointF p1out = MPPointF.getInstance1(0, 0);
    MPPointF p2out = MPPointF.getInstance1(0, 0);
    for (int j = 0; j < labelCount; j++) {
      for (int i = 0; i < _painter.getData().getEntryCount(); i++) {
        double r =
            (_painter.yAxis.entries[j] - _painter.getYChartMin()) * factor;

        Utils.getPosition(center, r, sliceangle * i + rotationangle, p1out);
        Utils.getPosition(
            center, r, sliceangle * (i + 1) + rotationangle, p2out);

        c.drawLine(
            Offset(p1out.x, p1out.y), Offset(p2out.x, p2out.y), _webPaint);
      }
    }
    MPPointF.recycleInstance(p1out);
    MPPointF.recycleInstance(p2out);
  }

  @override
  void drawHighlighted(Canvas c, List<Highlight> indices) {
    double sliceangle = _painter.getSliceAngle();

    // calculate the factor that is needed for transforming the value to
    // pixels
    double factor = _painter.getFactor();

    MPPointF center = _painter.getCenterOffsets();
    MPPointF pOut = MPPointF.getInstance1(0, 0);

    RadarData radarData = _painter.getData();

    for (Highlight high in indices) {
      IRadarDataSet set = radarData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled()) continue;

      RadarEntry e = set.getEntryForIndex(high.x.toInt());

      if (!isInBoundsX(e, set)) continue;

      double y = (e.y - _painter.getYChartMin());

      Utils.getPosition(
          center,
          y * factor * animator.getPhaseY(),
          sliceangle * high.x * animator.getPhaseX() +
              _painter.getRotationAngle(),
          pOut);

      high.setDraw(pOut.x, pOut.y);

      // draw the lines
      drawHighlightLines(c, pOut.x, pOut.y, set);

      if (set.isDrawHighlightCircleEnabled()) {
        if (!pOut.x.isNaN && !pOut.y.isNaN) {
          Color strokeColor = set.getHighlightCircleStrokeColor();
          if (strokeColor == ColorUtils.COLOR_NONE) {
            strokeColor = set.getColor2(0);
          }

          if (set.getHighlightCircleStrokeAlpha() < 255) {
            strokeColor = ColorUtils.colorWithAlpha(
                strokeColor, set.getHighlightCircleStrokeAlpha());
          }

          drawHighlightCircle(
              c,
              pOut,
              set.getHighlightCircleInnerRadius(),
              set.getHighlightCircleOuterRadius(),
              set.getHighlightCircleFillColor(),
              strokeColor,
              set.getHighlightCircleStrokeWidth());
        }
      }
    }

    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
  }

  Path mDrawHighlightCirclePathBuffer = new Path();

  void drawHighlightCircle(
      Canvas c,
      MPPointF point,
      double innerRadius,
      double outerRadius,
      Color fillColor,
      Color strokeColor,
      double strokeWidth) {
    c.save();

    outerRadius = Utils.convertDpToPixel(outerRadius);
    innerRadius = Utils.convertDpToPixel(innerRadius);

    if (fillColor != ColorUtils.COLOR_NONE) {
      Path p = mDrawHighlightCirclePathBuffer;
      p.reset();
      p.addOval(Rect.fromLTRB(point.x - outerRadius, point.y - outerRadius,
          point.x + outerRadius, point.y + outerRadius));
//      p.addCircle(point.x, point.y, outerRadius, Path.Direction.CW);
      if (innerRadius > 0.0) {
        p.addOval(Rect.fromLTRB(point.x - innerRadius, point.y - innerRadius,
            point.x + innerRadius, point.y + innerRadius));
//        p.addCircle(point.x, point.y, innerRadius, Path.Direction.CCW);
      }
      _highlightCirclePaint
        ..color = fillColor
        ..style = PaintingStyle.fill;
      c.drawPath(p, _highlightCirclePaint);
    }

    if (strokeColor != ColorUtils.COLOR_NONE) {
      _highlightCirclePaint
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = Utils.convertDpToPixel(strokeWidth);
      c.drawCircle(
          Offset(point.x, point.y), outerRadius, _highlightCirclePaint);
    }

    c.restore();
  }
}
