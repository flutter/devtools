import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/axis/x_axis.dart';
import 'package:mp_chart/mp/core/enums/limit_label_postion.dart';
import 'package:mp_chart/mp/core/enums/x_axis_position.dart';
import 'package:mp_chart/mp/core/limit_line.dart';
import 'package:mp_chart/mp/core/render/axis_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/poolable/size.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class XAxisRenderer extends AxisRenderer {
  XAxis _xAxis;

  XAxisRenderer(ViewPortHandler viewPortHandler, XAxis xAxis, Transformer trans)
      : super(viewPortHandler, trans, xAxis) {
    this._xAxis = xAxis;

    axisLabelPaint = PainterUtils.create(
        null, null, ColorUtils.BLACK, Utils.convertDpToPixel(10));
  }

  void setupGridPaint() {
    gridPaint = Paint()
      ..color = _xAxis.gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _xAxis.gridLineWidth;
  }

  XAxis get xAxis => _xAxis;

  @override
  void computeAxis(double min, double max, bool inverted) {
    // calculate the starting and entry point of the y-labels (depending on
    // zoom / contentrect bounds)
    if (viewPortHandler.contentWidth() > 10 &&
        !viewPortHandler.isFullyZoomedOutX()) {
      MPPointD p1 = trans.getValuesByTouchPoint1(
          viewPortHandler.contentLeft(), viewPortHandler.contentTop());
      MPPointD p2 = trans.getValuesByTouchPoint1(
          viewPortHandler.contentRight(), viewPortHandler.contentTop());

      if (inverted) {
        min = p2.x;
        max = p1.x;
      } else {
        min = p1.x;
        max = p2.x;
      }

      MPPointD.recycleInstance2(p1);
      MPPointD.recycleInstance2(p2);
    }

    computeAxisValues(min, max);
  }

  @override
  void computeAxisValues(double min, double max) {
    super.computeAxisValues(min, max);
    computeSize();
  }

  void computeSize() {
    String longest = _xAxis.getLongestLabel();

    axisLabelPaint = PainterUtils.create(
        axisLabelPaint, null, axisLabelPaint.text.style.color, _xAxis.textSize,
        fontWeight: _xAxis.typeface?.fontWeight,
        fontFamily: _xAxis.typeface?.fontFamily);

    final FSize labelSize = Utils.calcTextSize1(axisLabelPaint, longest);

    final double labelWidth = labelSize.width;
    final double labelHeight =
    Utils.calcTextHeight(axisLabelPaint, "Q").toDouble();

    final FSize labelRotatedSize = Utils.getSizeOfRotatedRectangleByDegrees(
        labelWidth, labelHeight, _xAxis.labelRotationAngle);

    _xAxis.labelWidth = labelWidth.round();
    _xAxis.labelHeight = labelHeight.round();
    _xAxis.labelRotatedWidth = labelRotatedSize.width.round();
    _xAxis.labelRotatedHeight = labelRotatedSize.height.round();

    FSize.recycleInstance(labelRotatedSize);
    FSize.recycleInstance(labelSize);
  }

  @override
  void renderAxisLabels(Canvas c) {
    if (!_xAxis.enabled || !_xAxis.drawLabels) return;

    axisLabelPaint.text = TextSpan(
        style: TextStyle(
            fontSize: _xAxis.textSize,
            color: _xAxis.textColor,
            fontFamily: _xAxis.typeface?.fontFamily,
            fontWeight: _xAxis.typeface?.fontWeight));

    MPPointF pointF = MPPointF.getInstance1(0, 0);
    if (_xAxis.position == XAxisPosition.TOP) {
      pointF.x = 0.5;
      pointF.y = 1.0;
      drawLabels(c, viewPortHandler.contentTop(), pointF, _xAxis.position);
    } else if (_xAxis.position == XAxisPosition.TOP_INSIDE) {
      pointF.x = 0.5;
      pointF.y = 1.0;
      drawLabels(c, viewPortHandler.contentTop() + _xAxis.labelRotatedHeight,
          pointF, _xAxis.position);
    } else if (_xAxis.position == XAxisPosition.BOTTOM) {
      pointF.x = 0.5;
      pointF.y = 0.0;
      drawLabels(c, viewPortHandler.contentBottom(), pointF, _xAxis.position);
    } else if (_xAxis.position == XAxisPosition.BOTTOM_INSIDE) {
      pointF.x = 0.5;
      pointF.y = 0.0;
      drawLabels(c, viewPortHandler.contentBottom() - _xAxis.labelRotatedHeight,
          pointF, _xAxis.position);
    } else {
      // BOTH SIDED
      pointF.x = 0.5;
      pointF.y = 1.0;
      drawLabels(c, viewPortHandler.contentTop(), pointF, XAxisPosition.TOP);
      pointF.x = 0.5;
      pointF.y = 0.0;
      drawLabels(
          c, viewPortHandler.contentBottom(), pointF, XAxisPosition.BOTTOM);
    }
    MPPointF.recycleInstance(pointF);
  }

  Path _axisLinePath = Path();

  @override
  void renderAxisLine(Canvas c) {
    if (!_xAxis.drawAxisLine || !_xAxis.enabled) return;

    axisLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _xAxis.axisLineColor
      ..strokeWidth = _xAxis.axisLineWidth;

    if (_xAxis.position == XAxisPosition.TOP ||
        _xAxis.position == XAxisPosition.TOP_INSIDE ||
        _xAxis.position == XAxisPosition.BOTH_SIDED) {
      _axisLinePath.reset();
      _axisLinePath.moveTo(
          viewPortHandler.contentLeft(), viewPortHandler.contentTop());
      _axisLinePath.lineTo(
          viewPortHandler.contentRight(), viewPortHandler.contentTop());
      if (xAxis.axisLineDashPathEffect != null) {
        _axisLinePath =
            xAxis.axisLineDashPathEffect.convert2DashPath(_axisLinePath);
      }
      c.drawPath(_axisLinePath, axisLinePaint);
    }

    if (_xAxis.position == XAxisPosition.BOTTOM ||
        _xAxis.position == XAxisPosition.BOTTOM_INSIDE ||
        _xAxis.position == XAxisPosition.BOTH_SIDED) {
      _axisLinePath.reset();
      _axisLinePath.moveTo(
          viewPortHandler.contentLeft(), viewPortHandler.contentBottom());
      _axisLinePath.lineTo(
          viewPortHandler.contentRight(), viewPortHandler.contentBottom());
      if (xAxis.axisLineDashPathEffect != null) {
        _axisLinePath =
            xAxis.axisLineDashPathEffect.convert2DashPath(_axisLinePath);
      }
      c.drawPath(_axisLinePath, axisLinePaint);
    }
  }

  /// draws the x-labels on the specified y-position
  ///
  /// @param pos
  void drawLabels(Canvas c, double pos, MPPointF anchor,
      XAxisPosition position) {
    final double labelRotationAngleDegrees = _xAxis.labelRotationAngle;
    bool centeringEnabled = _xAxis.isCenterAxisLabelsEnabled();

    List<double> positions = List(_xAxis.entryCount * 2);

    for (int i = 0; i < positions.length; i += 2) {
      // only fill x values
      if (centeringEnabled) {
        positions[i] = _xAxis.centeredEntries[i ~/ 2];
      } else {
        positions[i] = _xAxis.entries[i ~/ 2];
      }
      positions[i + 1] = 0;
    }

    trans.pointValuesToPixel(positions);

    for (int i = 0; i < positions.length; i += 2) {
      double x = positions[i];

      if (viewPortHandler.isInBoundsX(x)) {
        String label = _xAxis
            .getValueFormatter()
            .getAxisLabel(_xAxis.entries[i ~/ 2], _xAxis);

        if (_xAxis.avoidFirstLastClipping) {
          // avoid clipping of the last
          if (i / 2 == _xAxis.entryCount - 1 && _xAxis.entryCount > 1) {
            double width =
            Utils.calcTextWidth(axisLabelPaint, label).toDouble();

            if (width > viewPortHandler.offsetRight() * 2 &&
                x + width > viewPortHandler.getChartWidth()) x -= width / 2;

            // avoid clipping of the first
          } else if (i == 0) {
            double width =
            Utils.calcTextWidth(axisLabelPaint, label).toDouble();
            x += width / 2;
          }
        }

        drawLabel(
            c,
            label,
            x,
            pos,
            anchor,
            labelRotationAngleDegrees,
            position);
      }
    }
  }

  void drawLabel(Canvas c, String formattedLabel, double x, double y,
      MPPointF anchor, double angleDegrees, XAxisPosition position) {
    Utils.drawXAxisValue(
        c,
        formattedLabel,
        x,
        y,
        axisLabelPaint,
        anchor,
        angleDegrees,
        position);
  }

  Path mRenderGridLinesPath = Path();
  List<double> mRenderGridLinesBuffer = List(2);

  @override
  void renderGridLines(Canvas c) {
    if (!_xAxis.drawGridLines || !_xAxis.enabled) return;

    c.save();
    c.clipRect(getGridClippingRect());

    if (mRenderGridLinesBuffer.length != axis.entryCount * 2) {
      mRenderGridLinesBuffer = List(_xAxis.entryCount * 2);
    }
    List<double> positions = mRenderGridLinesBuffer;

    for (int i = 0; i < positions.length; i += 2) {
      positions[i] = _xAxis.entries[i ~/ 2];
      positions[i + 1] = _xAxis.entries[i ~/ 2];
    }
    trans.pointValuesToPixel(positions);

    setupGridPaint();

    Path gridLinePath = mRenderGridLinesPath;
    gridLinePath.reset();

    for (int i = 0; i < positions.length; i += 2) {
      drawGridLine(c, positions[i], positions[i + 1], gridLinePath);
    }

    c.restore();
  }

  Rect mGridClippingRect = Rect.zero;

  Rect getGridClippingRect() {
    mGridClippingRect = Rect.fromLTRB(
        viewPortHandler
            .getContentRect()
            .left - axis.gridLineWidth,
        viewPortHandler
            .getContentRect()
            .top - axis.gridLineWidth,
        viewPortHandler
            .getContentRect()
            .right,
        viewPortHandler
            .getContentRect()
            .bottom);
    return mGridClippingRect;
  }

  /// Draws the grid line at the specified position using the provided path.
  ///
  /// @param c
  /// @param x
  /// @param y
  /// @param gridLinePath
  void drawGridLine(Canvas c, double x, double y, Path path) {
    path.moveTo(x, viewPortHandler.contentBottom());
    path.lineTo(x, viewPortHandler.contentTop());

    // draw a path because lines don't support dashing on lower android versions
    if (xAxis.gridDashPathEffect != null) {
      path = xAxis.gridDashPathEffect.convert2DashPath(path);
    }

    c.drawPath(path, gridPaint);

    path.reset();
  }

  List<double> mRenderLimitLinesBuffer = List(2);
  Rect mLimitLineClippingRect = Rect.zero;

  /// Draws the LimitLines associated with this axis to the screen.
  ///
  /// @param c
  @override
  void renderLimitLines(Canvas c) {
    List<LimitLine> limitLines = _xAxis.getLimitLines();

    if (limitLines == null || limitLines.length <= 0) return;

    List<double> position = mRenderLimitLinesBuffer;
    position[0] = 0;
    position[1] = 0;

    for (int i = 0; i < limitLines.length; i++) {
      LimitLine l = limitLines[i];

      if (!l.enabled) continue;

      c.save();
      mLimitLineClippingRect = Rect.fromLTRB(
          viewPortHandler
              .getContentRect()
              .left - l.lineWidth,
          viewPortHandler
              .getContentRect()
              .top - l.lineWidth,
          viewPortHandler
              .getContentRect()
              .right,
          viewPortHandler
              .getContentRect()
              .bottom);
      c.clipRect(mLimitLineClippingRect);

      position[0] = l.limit;
      position[1] = 0;

      trans.pointValuesToPixel(position);

      renderLimitLineLine(c, l, position);
      renderLimitLineLabel(c, l, position, 2.0 + l.yOffset);

      c.restore();
    }
  }

  List<double> _limitLineSegmentsBuffer = List(4);
  Path _limitLinePath = Path();

  void renderLimitLineLine(Canvas c, LimitLine limitLine,
      List<double> position) {
    _limitLineSegmentsBuffer[0] = position[0];
    _limitLineSegmentsBuffer[1] = viewPortHandler.contentTop();
    _limitLineSegmentsBuffer[2] = position[0];
    _limitLineSegmentsBuffer[3] = viewPortHandler.contentBottom();

    _limitLinePath.reset();
    _limitLinePath.moveTo(
        _limitLineSegmentsBuffer[0], _limitLineSegmentsBuffer[1]);
    _limitLinePath.lineTo(
        _limitLineSegmentsBuffer[2], _limitLineSegmentsBuffer[3]);

    limitLinePaint
      ..style = PaintingStyle.stroke
      ..color = limitLine.lineColor
      ..strokeWidth = limitLine.lineWidth;

    if (limitLine.dashPathEffect != null) {
      _limitLinePath =
          limitLine.dashPathEffect.convert2DashPath(_limitLinePath);
    }
    c.drawPath(_limitLinePath, limitLinePaint);
  }

  void renderLimitLineLabel(Canvas c, LimitLine limitLine,
      List<double> position, double yOffset) {
    String label = limitLine.label;

    // if drawing the limit-value label is enabled
    if (label != null && label.isNotEmpty) {
      var painter = PainterUtils.create(
          null, label, limitLine.textColor, limitLine.textSize,
          fontFamily: limitLine.typeface?.fontFamily,
          fontWeight: limitLine.typeface?.fontWeight);

      double xOffset = limitLine.lineWidth + limitLine.xOffset;

      final LimitLabelPosition labelPosition = limitLine.labelPosition;

      if (labelPosition == LimitLabelPosition.RIGHT_TOP) {
        final double labelLineHeight =
        Utils.calcTextHeight(painter, label).toDouble();
        painter.textAlign = TextAlign.left;
        painter.layout();
        var offset = Offset(position[0] + xOffset,
            viewPortHandler.contentTop() + yOffset + labelLineHeight);
        CanvasUtils.renderLimitLabelBackground(c, painter, offset, limitLine);
        painter.paint(c, offset);
      } else if (labelPosition == LimitLabelPosition.RIGHT_BOTTOM) {
        painter.textAlign = TextAlign.left;
        painter.layout();
        var offset = Offset(position[0] + xOffset,
            viewPortHandler.contentBottom() - yOffset - painter.height);
        CanvasUtils.renderLimitLabelBackground(c, painter, offset, limitLine);
        painter.paint(c, offset);
      } else if (labelPosition == LimitLabelPosition.CENTER_TOP) {
        final double labelLineHeight =
        Utils.calcTextHeight(painter, label).toDouble();
        painter.textAlign = TextAlign.left;
        painter.layout();
        var offset = Offset(position[0] - painter.width / 2,
            viewPortHandler.contentTop() + yOffset + labelLineHeight);
        CanvasUtils.renderLimitLabelBackground(c, painter, offset, limitLine);
        painter.paint(c, offset);
      } else if (labelPosition == LimitLabelPosition.CENTER_BOTTOM) {
        painter.textAlign = TextAlign.right;
        painter.layout();
        var offset = Offset(position[0] - painter.width / 2,
            viewPortHandler.contentBottom() - yOffset - painter.height);
        CanvasUtils.renderLimitLabelBackground(c, painter, offset, limitLine);
        painter.paint(c, offset);
      } else if (labelPosition == LimitLabelPosition.LEFT_TOP) {
        painter.textAlign = TextAlign.right;
        final double labelLineHeight =
        Utils.calcTextHeight(painter, label).toDouble();
        painter.layout();
        var offset = Offset(position[0] - xOffset - painter.width,
            viewPortHandler.contentTop() + yOffset + labelLineHeight);
        CanvasUtils.renderLimitLabelBackground(c, painter, offset, limitLine);
        painter.paint(c, offset);
      } else {
        painter.textAlign = TextAlign.right;
        painter.layout();
        var offset = Offset(position[0] - xOffset - painter.width,
            viewPortHandler.contentBottom() - yOffset - painter.height);
        CanvasUtils.renderLimitLabelBackground(c, painter, offset, limitLine);
        painter.paint(c, offset);
      }
    }
  }
}
