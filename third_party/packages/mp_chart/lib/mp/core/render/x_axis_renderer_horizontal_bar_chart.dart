import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/enums/limit_label_postion.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/limit_line.dart';
import 'package:mp_chart/mp/core/render/x_axis_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/poolable/size.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class XAxisRendererHorizontalBarChart extends XAxisRenderer {
  XAxisRendererHorizontalBarChart(
      ViewPortHandler viewPortHandler, XAxis xAxis, Transformer trans)
      : super(viewPortHandler, xAxis, trans);

  @override
  void computeAxis(double min, double max, bool inverted) {
    // calculate the starting and entry point of the y-labels (depending on
    // zoom / contentrect bounds)
    if (viewPortHandler.contentWidth() > 10 &&
        !viewPortHandler.isFullyZoomedOutY()) {
      MPPointD p1 = trans.getValuesByTouchPoint1(
          viewPortHandler.contentLeft(), viewPortHandler.contentBottom());
      MPPointD p2 = trans.getValuesByTouchPoint1(
          viewPortHandler.contentLeft(), viewPortHandler.contentTop());

      if (inverted) {
        min = p2.y;
        max = p1.y;
      } else {
        min = p1.y;
        max = p2.y;
      }

      MPPointD.recycleInstance2(p1);
      MPPointD.recycleInstance2(p2);
    }

    computeAxisValues(min, max);
  }

  @override
  void computeSize() {
    axisLabelPaint = PainterUtils.create(
        axisLabelPaint,
        null,
        axisLabelPaint.text.style.color == null
            ? ColorUtils.HOLO_GREEN_DARK
            : axisLabelPaint.text.style.color,
        xAxis.textSize,
        fontWeight: xAxis.typeface?.fontWeight,
        fontFamily: xAxis.typeface?.fontFamily);

    String longest = xAxis.getLongestLabel();

    final FSize labelSize = Utils.calcTextSize1(axisLabelPaint, longest);

    final double labelWidth =
        (labelSize.width + xAxis.xOffset * 3.5).toInt().toDouble();
    final double labelHeight = labelSize.height;

    final FSize labelRotatedSize = Utils.getSizeOfRotatedRectangleByDegrees(
        labelSize.width, labelHeight, xAxis.labelRotationAngle);

    xAxis.labelWidth = labelWidth.round();
    xAxis.labelHeight = labelHeight.round();
    xAxis.labelRotatedWidth =
        (labelRotatedSize.width + xAxis.xOffset * 3.5).toInt();
    xAxis.labelRotatedHeight = labelRotatedSize.height.round();

    FSize.recycleInstance(labelRotatedSize);
  }

  @override
  void renderAxisLabels(Canvas c) {
    if (!xAxis.enabled || !xAxis.drawLabels) return;

    axisLabelPaint = PainterUtils.create(
        axisLabelPaint, null, xAxis.textColor, xAxis.textSize,
        fontFamily: xAxis.typeface?.fontFamily,
        fontWeight: xAxis.typeface?.fontWeight);

    MPPointF pointF = MPPointF.getInstance1(0, 0);

    if (xAxis.position == XAxisPosition.TOP) {
      pointF.x = 0.0;
      pointF.y = 0.5;
      drawLabels(c, viewPortHandler.contentRight(), pointF, xAxis.position);
    } else if (xAxis.position == XAxisPosition.TOP_INSIDE) {
      pointF.x = 1.0;
      pointF.y = 0.5;
      drawLabels(c, viewPortHandler.contentRight(), pointF, xAxis.position);
    } else if (xAxis.position == XAxisPosition.BOTTOM) {
      pointF.x = 1.0;
      pointF.y = 0.5;
      drawLabels(c, viewPortHandler.contentLeft(), pointF, xAxis.position);
    } else if (xAxis.position == XAxisPosition.BOTTOM_INSIDE) {
      pointF.x = 1.0;
      pointF.y = 0.5;
      drawLabels(c, viewPortHandler.contentLeft(), pointF, xAxis.position);
    } else {
      // BOTH SIDED
      pointF.x = 0.0;
      pointF.y = 0.5;
      drawLabels(c, viewPortHandler.contentRight(), pointF, xAxis.position);
      pointF.x = 1.0;
      pointF.y = 0.5;
      drawLabels(c, viewPortHandler.contentLeft(), pointF, xAxis.position);
    }

    MPPointF.recycleInstance(pointF);
  }

  @override
  void drawLabels(
      Canvas c, double pos, MPPointF anchor, XAxisPosition position) {
    final double labelRotationAngleDegrees = xAxis.labelRotationAngle;
    bool centeringEnabled = xAxis.isCenterAxisLabelsEnabled();

    List<double> positions = List(xAxis.entryCount * 2);

    for (int i = 0; i < positions.length; i += 2) {
      // only fill x values
      if (centeringEnabled) {
        positions[i + 1] = xAxis.centeredEntries[i ~/ 2];
      } else {
        positions[i + 1] = xAxis.entries[i ~/ 2];
      }
    }

    trans.pointValuesToPixel(positions);

    for (int i = 0; i < positions.length; i += 2) {
      double y = positions[i + 1];

      if (viewPortHandler.isInBoundsY(y)) {
        String label = xAxis
            .getValueFormatter()
            .getAxisLabel(xAxis.entries[i ~/ 2], xAxis);
        Utils.drawXAxisValueHorizontal(c, label, pos, y, axisLabelPaint, anchor,
            labelRotationAngleDegrees, position);
      }
    }
  }

  @override
  Rect getGridClippingRect() {
    mGridClippingRect = Rect.fromLTRB(
        viewPortHandler.getContentRect().left,
        viewPortHandler.getContentRect().top,
        viewPortHandler.getContentRect().right + axis.gridLineWidth,
        viewPortHandler.getContentRect().bottom + axis.gridLineWidth);
    return mGridClippingRect;
  }

  @override
  void drawGridLine(Canvas c, double x, double y, Path gridLinePath) {
    gridLinePath.moveTo(viewPortHandler.contentRight(), y);
    gridLinePath.lineTo(viewPortHandler.contentLeft(), y);

    // draw a path because lines don't support dashing on lower android versions
    c.drawPath(gridLinePath, gridPaint);

    gridLinePath.reset();
  }

  @override
  void renderAxisLine(Canvas c) {
    if (!xAxis.drawAxisLine || !xAxis.enabled) return;

    axisLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = xAxis.axisLineColor
      ..strokeWidth = xAxis.axisLineWidth;

    if (xAxis.position == XAxisPosition.TOP ||
        xAxis.position == XAxisPosition.TOP_INSIDE ||
        xAxis.position == XAxisPosition.BOTH_SIDED) {
      c.drawLine(
          Offset(viewPortHandler.contentRight(), viewPortHandler.contentTop()),
          Offset(
              viewPortHandler.contentRight(), viewPortHandler.contentBottom()),
          axisLinePaint);
    }

    if (xAxis.position == XAxisPosition.BOTTOM ||
        xAxis.position == XAxisPosition.BOTTOM_INSIDE ||
        xAxis.position == XAxisPosition.BOTH_SIDED) {
      c.drawLine(
          Offset(viewPortHandler.contentLeft(), viewPortHandler.contentTop()),
          Offset(
              viewPortHandler.contentLeft(), viewPortHandler.contentBottom()),
          axisLinePaint);
    }
  }

  Path mRenderLimitLinesPathBuffer = Path();

  /// Draws the LimitLines associated with this axis to the screen.
  /// This is the standard YAxis renderer using the XAxis limit lines.
  ///
  /// @param c
  @override
  void renderLimitLines(Canvas c) {
    List<LimitLine> limitLines = xAxis.getLimitLines();

    if (limitLines == null || limitLines.length <= 0) return;

    List<double> pts = mRenderLimitLinesBuffer;
    pts[0] = 0;
    pts[1] = 0;

    Path limitLinePath = mRenderLimitLinesPathBuffer;
    limitLinePath.reset();

    for (int i = 0; i < limitLines.length; i++) {
      LimitLine l = limitLines[i];

      if (!l.enabled) continue;

      c.save();
      mLimitLineClippingRect = Rect.fromLTRB(
          viewPortHandler.getContentRect().left,
          viewPortHandler.getContentRect().top,
          viewPortHandler.getContentRect().right + l.lineWidth,
          viewPortHandler.getContentRect().bottom + l.lineWidth);
      c.clipRect(mLimitLineClippingRect);

      limitLinePaint
        ..style = PaintingStyle.stroke
        ..color = l.lineColor
        ..strokeWidth = l.lineWidth;

      pts[1] = l.limit;

      trans.pointValuesToPixel(pts);

      limitLinePath.moveTo(viewPortHandler.contentLeft(), pts[1]);
      limitLinePath.lineTo(viewPortHandler.contentRight(), pts[1]);

      if (l.dashPathEffect != null) {
        limitLinePath = l.dashPathEffect.convert2DashPath(limitLinePath);
      }
      c.drawPath(limitLinePath, limitLinePaint);
      limitLinePath.reset();

      String label = l.label;

      // if drawing the limit-value label is enabled
      if (label != null && label.isNotEmpty) {
        final double labelLineHeight =
            Utils.calcTextHeight(axisLabelPaint, label).toDouble();
        double xOffset = l.xOffset;
        double yOffset = l.lineWidth + labelLineHeight + l.yOffset;

        final LimitLabelPosition position = l.labelPosition;

        if (position == LimitLabelPosition.RIGHT_TOP) {
          axisLabelPaint = PainterUtils.create(
              axisLabelPaint, label, l.textColor, l.textSize);
          axisLabelPaint.layout();
          var offset = Offset(
              viewPortHandler.contentRight() - xOffset - axisLabelPaint.width,
              pts[1] - yOffset);
          CanvasUtils.renderLimitLabelBackground(c, axisLabelPaint, offset, l);
          axisLabelPaint.paint(c, offset);
        } else if (position == LimitLabelPosition.RIGHT_BOTTOM) {
          axisLabelPaint = PainterUtils.create(
              axisLabelPaint, label, l.textColor, l.textSize);
          axisLabelPaint.layout();
          var offset = Offset(
              viewPortHandler.contentRight() - xOffset - axisLabelPaint.width,
              pts[1] + yOffset);
          CanvasUtils.renderLimitLabelBackground(c, axisLabelPaint, offset, l);
          axisLabelPaint.paint(c, offset);
        } else if (position == LimitLabelPosition.RIGHT_CENTER) {
          axisLabelPaint = PainterUtils.create(
              axisLabelPaint, label, l.textColor, l.textSize);
          axisLabelPaint.layout();
          var offset = Offset(
              viewPortHandler.contentRight() - xOffset - axisLabelPaint.width,
              pts[1] - axisLabelPaint.height / 2);
          CanvasUtils.renderLimitLabelBackground(c, axisLabelPaint, offset, l);
          axisLabelPaint.paint(c, offset);
        } else if (position == LimitLabelPosition.LEFT_CENTER) {
          axisLabelPaint = PainterUtils.create(
              axisLabelPaint, label, l.textColor, l.textSize);
          axisLabelPaint.layout();
          var offset = Offset(viewPortHandler.contentLeft() + xOffset,
              pts[1] - axisLabelPaint.height / 2);
          CanvasUtils.renderLimitLabelBackground(c, axisLabelPaint, offset, l);
          axisLabelPaint.paint(c, offset);
        } else if (position == LimitLabelPosition.LEFT_TOP) {
          axisLabelPaint = PainterUtils.create(
              axisLabelPaint, label, l.textColor, l.textSize);
          axisLabelPaint.layout();
          var offset =
              Offset(viewPortHandler.contentLeft() + xOffset, pts[1] - yOffset);
          CanvasUtils.renderLimitLabelBackground(c, axisLabelPaint, offset, l);
          axisLabelPaint.paint(c, offset);
        } else {
          axisLabelPaint = PainterUtils.create(
              axisLabelPaint, label, l.textColor, l.textSize);
          axisLabelPaint.layout();
          var offset =
              Offset(viewPortHandler.offsetLeft() + xOffset, pts[1] + yOffset);
          CanvasUtils.renderLimitLabelBackground(c, axisLabelPaint, offset, l);
          axisLabelPaint.paint(c, offset);
        }
      }

      c.restore();
    }
  }
}
