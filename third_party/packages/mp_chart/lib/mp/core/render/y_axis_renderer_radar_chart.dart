import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/limit_line.dart';
import 'package:mp_chart/mp/core/render/y_axis_renderer.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/painter/radar_chart_painter.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class YAxisRendererRadarChart extends YAxisRenderer {
  RadarChartPainter _painter;

  YAxisRendererRadarChart(
      ViewPortHandler viewPortHandler, YAxis yAxis, RadarChartPainter chart)
      : super(viewPortHandler, yAxis, null) {
    this._painter = chart;
  }

  RadarChartPainter get painter => _painter;

  @override
  void computeAxisValues(double min, double max) {
    double yMin = min;
    double yMax = max;

    int labelCount = axis.labelCount;
    double range = (yMax - yMin).abs();

    if (labelCount == 0 || range <= 0 || range.isInfinite) {
      axis.entries = List();
      axis.centeredEntries = List();
      axis.entryCount = 0;
      return;
    }

    // Find out how much spacing (in y value space) between axis values
    double rawInterval = range / labelCount;
    double interval = Utils.roundToNextSignificant(rawInterval);

    // If granularity is enabled, then do not allow the interval to go below specified granularity.
    // This is used to avoid repeated values when rounding values for display.
    if (axis.granularityEnabled)
      interval = interval < axis.granularity ? axis.granularity : interval;

    // Normalize interval
    double intervalMagnitude =
        Utils.roundToNextSignificant(pow(10.0, log(interval) / ln10));
    int intervalSigDigit = (interval ~/ intervalMagnitude);
    if (intervalSigDigit > 5) {
      // Use one order of magnitude higher, to avoid intervals like 0.9 or
      // 90
      interval = (10 * intervalMagnitude).floor().toDouble();
    }

    bool centeringEnabled = axis.isCenterAxisLabelsEnabled();
    int n = centeringEnabled ? 1 : 0;

    // force label count
    if (axis.forceLabels) {
      double step = range / (labelCount - 1);
      axis.entryCount = labelCount;

      if (axis.entries.length < labelCount) {
        // Ensure stops contains at least numStops elements.
        axis.entries = List(labelCount);
      }

      double v = min;

      for (int i = 0; i < labelCount; i++) {
        axis.entries[i] = v;
        v += step;
      }

      n = labelCount;

      // no forced count
    } else {
      double first =
          interval == 0.0 ? 0.0 : (yMin / interval).ceil() * interval;
      if (centeringEnabled) {
        first -= interval;
      }

      double last = interval == 0.0
          ? 0.0
          : Utils.nextUp((yMax / interval).floor() * interval);

      double f;
      int i;

      if (interval != 0.0) {
        for (f = first; f <= last; f += interval) {
          ++n;
        }
      }

      n++;

      axis.entryCount = n;

      if (axis.entries.length < n) {
        // Ensure stops contains at least numStops elements.
        axis.entries = List(n);
      }

      f = first;
      for (i = 0; i < n; f += interval, ++i) {
        if (f ==
            0.0) // Fix for negative zero case (Where value == -0.0, and 0.0 == -0.0)
          f = 0.0;

        axis.entries[i] = f.toDouble();
      }
    }

    // set decimals
    if (interval < 1) {
      axis.decimals = (-log(interval) / ln10).ceil();
    } else {
      axis.decimals = 0;
    }

    if (centeringEnabled) {
      if (axis.centeredEntries.length < n) {
        axis.centeredEntries = List(n);
      }

      double offset = (axis.entries[1] - axis.entries[0]) / 2;

      for (int i = 0; i < n; i++) {
        axis.centeredEntries[i] = axis.entries[i] + offset;
      }
    }

    axis.axisMinimum = axis.entries[0];
    axis.axisMaximum = axis.entries[n - 1];
    axis.axisRange = (axis.axisMaximum - axis.axisMinimum).abs();
  }

  @override
  void renderAxisLabels(Canvas c) {
    if (!yAxis.enabled || !yAxis.drawLabels) return;

//    axisLabelPaint.setTypeface(yAxis.getTypeface());

    MPPointF center = _painter.getCenterOffsets();
    MPPointF pOut = MPPointF.getInstance1(0, 0);
    double factor = _painter.getFactor();

    final int from = yAxis.drawBottomYLabelEntry ? 0 : 1;
    final int to =
        yAxis.drawTopYLabelEntry ? yAxis.entryCount : (yAxis.entryCount - 1);

    for (int j = from; j < to; j++) {
      double r = (yAxis.entries[j] - yAxis.axisMinimum) * factor;

      Utils.getPosition(center, r, _painter.getRotationAngle(), pOut);

      String label = yAxis.getFormattedLabel(j);
      axisLabelPaint = PainterUtils.create(
          axisLabelPaint, label, yAxis.textColor, yAxis.textSize,
          fontWeight: yAxis.typeface?.fontWeight,
          fontFamily: yAxis.typeface?.fontFamily);
      axisLabelPaint.layout();
      axisLabelPaint.paint(
          c,
          Offset(pOut.x + 10 - axisLabelPaint.width,
              pOut.y - axisLabelPaint.height));
    }
    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
  }

  Path mRenderLimitLinesPathBuffer = new Path();

  @override
  void renderLimitLines(Canvas c) {
    List<LimitLine> limitLines = yAxis.getLimitLines();

    if (limitLines == null) return;

    double sliceangle = _painter.getSliceAngle();

    // calculate the factor that is needed for transforming the value to
    // pixels
    double factor = _painter.getFactor();

    MPPointF center = _painter.getCenterOffsets();
    MPPointF pOut = MPPointF.getInstance1(0, 0);
    for (int i = 0; i < limitLines.length; i++) {
      LimitLine l = limitLines[i];

      if (!l.enabled) continue;

      limitLinePaint
        ..style = PaintingStyle.stroke
        ..color = (l.lineColor)
        ..strokeWidth = l.lineWidth;

      double r = (l.limit - _painter.getYChartMin()) * factor;

      Path limitPath = mRenderLimitLinesPathBuffer;
      limitPath.reset();

      for (int j = 0;
          j < _painter.getData().getMaxEntryCountSet().getEntryCount();
          j++) {
        Utils.getPosition(
            center, r, sliceangle * j + _painter.getRotationAngle(), pOut);

        if (j == 0)
          limitPath.moveTo(pOut.x, pOut.y);
        else
          limitPath.lineTo(pOut.x, pOut.y);
      }
      limitPath.close();

      if (l.dashPathEffect != null) {
        limitPath = l.dashPathEffect.convert2DashPath(limitPath);
      }
      c.drawPath(limitPath, limitLinePaint);
    }
    MPPointF.recycleInstance(center);
    MPPointF.recycleInstance(pOut);
  }
}
