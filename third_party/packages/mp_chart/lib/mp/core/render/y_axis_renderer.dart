import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/axis/y_axis.dart';
import 'package:mp_chart/mp/core/enums/axis_dependency.dart';
import 'package:mp_chart/mp/core/enums/limit_label_postion.dart';
import 'package:mp_chart/mp/core/enums/y_axis_label_position.dart';
import 'package:mp_chart/mp/core/limit_line.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/render/axis_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';

class YAxisRenderer extends AxisRenderer {
  YAxis _yAxis;

  Paint _zeroLinePaint;

  YAxisRenderer(ViewPortHandler viewPortHandler, YAxis yAxis, Transformer trans)
      : super(viewPortHandler, trans, yAxis) {
    this._yAxis = yAxis;

    if (viewPortHandler != null) {
      axisLabelPaint = PainterUtils.create(
          axisLabelPaint, null, ColorUtils.BLACK, Utils.convertDpToPixel(10));

      _zeroLinePaint = Paint()
        ..color = ColorUtils.GRAY
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
    }
  }

  YAxis get yAxis => _yAxis;

  // ignore: unnecessary_getters_setters
  Paint get zeroLinePaint => _zeroLinePaint;

  // ignore: unnecessary_getters_setters
  set zeroLinePaint(Paint value) {
    _zeroLinePaint = value;
  }

  /// draws the y-axis labels to the screen
  @override
  void renderAxisLabels(Canvas c) {
    if (!_yAxis.enabled || !_yAxis.drawLabels) return;

    List<double> positions = getTransformedPositions();

    AxisDependency dependency = _yAxis.axisDependency;
    YAxisLabelPosition labelPosition = _yAxis.position;

    double xPos = 0;

    axisLabelPaint = PainterUtils.create(
        axisLabelPaint, null, _yAxis.textColor, _yAxis.textSize,
        fontFamily: _yAxis.typeface?.fontFamily,
        fontWeight: _yAxis.typeface?.fontWeight);
    if (dependency == AxisDependency.LEFT) {
      if (labelPosition == YAxisLabelPosition.OUTSIDE_CHART) {
        xPos = viewPortHandler.offsetLeft();
      } else {
        xPos = viewPortHandler.offsetLeft();
      }
    } else {
      if (labelPosition == YAxisLabelPosition.OUTSIDE_CHART) {
        xPos = viewPortHandler.contentRight();
      } else {
        xPos = viewPortHandler.contentRight();
      }
    }

    drawYLabels(c, xPos, positions, dependency, labelPosition);
  }

  @override
  void renderAxisLine(Canvas c) {
    if (!_yAxis.enabled || !_yAxis.drawAxisLine) return;

    axisLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = _yAxis.axisLineColor
      ..strokeWidth = _yAxis.axisLineWidth;

    _renderGridLinesPath.reset();
    if (_yAxis.axisDependency == AxisDependency.LEFT) {
      _renderGridLinesPath.moveTo(
          viewPortHandler.contentLeft(), viewPortHandler.contentTop());
      _renderGridLinesPath.lineTo(
          viewPortHandler.contentLeft(), viewPortHandler.contentBottom());
      if (_yAxis.axisLineDashPathEffect != null) {
        _renderGridLinesPath = _yAxis.axisLineDashPathEffect
            .convert2DashPath(_renderGridLinesPath);
      }
      c.drawPath(_renderGridLinesPath, axisLinePaint);
    } else {
      _renderGridLinesPath.moveTo(
          viewPortHandler.contentRight(), viewPortHandler.contentTop());
      _renderGridLinesPath.lineTo(
          viewPortHandler.contentRight(), viewPortHandler.contentBottom());
      if (_yAxis.axisLineDashPathEffect != null) {
        _renderGridLinesPath = _yAxis.axisLineDashPathEffect
            .convert2DashPath(_renderGridLinesPath);
      }
      c.drawPath(_renderGridLinesPath, axisLinePaint);
    }
  }

  /// draws the y-labels on the specified x-position
  ///
  /// @param fixedPosition
  /// @param positions
  void drawYLabels(
    Canvas c,
    double fixedPosition,
    List<double> positions,
    AxisDependency axisDependency,
    YAxisLabelPosition position,
  ) {
    final int from = _yAxis.drawBottomYLabelEntry ? 0 : 1;
    final int to =
        _yAxis.drawTopYLabelEntry ? _yAxis.entryCount : (_yAxis.entryCount - 1);

    // draw
    for (int i = from; i < to; i++) {
      String text = _yAxis.getFormattedLabel(i);

      axisLabelPaint.text =
          TextSpan(text: text, style: axisLabelPaint.text.style);
      axisLabelPaint.layout();
      if (axisDependency == AxisDependency.LEFT) {
        if (position == YAxisLabelPosition.OUTSIDE_CHART) {
          axisLabelPaint.paint(
              c,
              Offset(fixedPosition - axisLabelPaint.width,
                  positions[i * 2 + 1] - axisLabelPaint.height / 2));
        } else {
          axisLabelPaint.paint(
              c,
              Offset(fixedPosition,
                  positions[i * 2 + 1] - axisLabelPaint.height / 2));
        }
      } else {
        if (position == YAxisLabelPosition.OUTSIDE_CHART) {
          axisLabelPaint.paint(
              c,
              Offset(fixedPosition,
                  positions[i * 2 + 1] - axisLabelPaint.height / 2));
        } else {
          axisLabelPaint.paint(
              c,
              Offset(fixedPosition - axisLabelPaint.width,
                  positions[i * 2 + 1] - axisLabelPaint.height / 2));
        }
      }
    }
  }

  Path _renderGridLinesPath = Path();

  @override
  void renderGridLines(Canvas c) {
    if (!_yAxis.enabled) return;

    if (_yAxis.drawGridLines) {
      c.save();
      c.clipRect(getGridClippingRect());

      List<double> positions = getTransformedPositions();

      gridPaint
        ..style = PaintingStyle.stroke
        ..color = _yAxis.gridColor
        ..strokeWidth = _yAxis.gridLineWidth;

      Path gridLinePath = _renderGridLinesPath;
      gridLinePath.reset();

      // draw the grid
      for (int i = 0; i < positions.length; i += 2) {
        // draw a path because lines don't support dashing on lower android versions
        if (yAxis.gridDashPathEffect != null) {
          c.drawPath(
              yAxis.gridDashPathEffect
                  .convert2DashPath(linePath(gridLinePath, i, positions)),
              gridPaint);
        } else {
          c.drawPath(linePath(gridLinePath, i, positions), gridPaint);
        }
        gridLinePath.reset();
      }

      c.restore();
    }

    if (_yAxis.drawZeroLine) {
      drawZeroLine(c);
    }
  }

  Rect _gridClippingRect = Rect.zero;

  Rect getGridClippingRect() {
    _gridClippingRect = Rect.fromLTRB(
        viewPortHandler.getContentRect().left,
        viewPortHandler.getContentRect().top,
        viewPortHandler.getContentRect().right + axis.gridLineWidth,
        viewPortHandler.getContentRect().bottom + axis.gridLineWidth);
    return _gridClippingRect;
  }

  /// Calculates the path for a grid line.
  ///
  /// @param p
  /// @param i
  /// @param positions
  /// @return
  Path linePath(Path p, int i, List<double> positions) {
    p.moveTo(viewPortHandler.offsetLeft(), positions[i + 1]);
    p.lineTo(viewPortHandler.contentRight(), positions[i + 1]);

    return p;
  }

  List<double> mGetTransformedPositionsBuffer = List(2);

  /// Transforms the values contained in the axis entries to screen pixels and returns them in form of a double array
  /// of x- and y-coordinates.
  ///
  /// @return
  List<double> getTransformedPositions() {
    if (mGetTransformedPositionsBuffer.length != _yAxis.entryCount * 2) {
      mGetTransformedPositionsBuffer = List(_yAxis.entryCount * 2);
    }
    List<double> positions = mGetTransformedPositionsBuffer;

    for (int i = 0; i < positions.length; i += 2) {
      // only fill y values, x values are not needed for y-labels
      positions[i] = 0.0;
      positions[i + 1] = _yAxis.entries[i ~/ 2];
    }

    trans.pointValuesToPixel(positions);
    return positions;
  }

  Path _drawZeroLinePath = Path();
  Rect _zeroLineClippingRect = Rect.zero;

  /// Draws the zero line.
  void drawZeroLine(Canvas c) {
    c.save();
    _zeroLineClippingRect = Rect.fromLTRB(
        viewPortHandler.getContentRect().left,
        viewPortHandler.getContentRect().top,
        viewPortHandler.getContentRect().right + _yAxis.zeroLineWidth,
        viewPortHandler.getContentRect().bottom + _yAxis.zeroLineWidth);
    c.clipRect(_zeroLineClippingRect);

    // draw zero line
    MPPointD pos = trans.getPixelForValues(0, 0);

    _zeroLinePaint
      ..style = PaintingStyle.stroke
      ..color = _yAxis.zeroLineColor
      ..strokeWidth = _yAxis.zeroLineWidth;

    Path zeroLinePath = _drawZeroLinePath;
    zeroLinePath.reset();

    zeroLinePath.moveTo(viewPortHandler.contentLeft(), pos.y);
    zeroLinePath.lineTo(viewPortHandler.contentRight(), pos.y);

    // draw a path because lines don't support dashing on lower android versions
    c.drawPath(zeroLinePath, _zeroLinePaint);

    c.restore();
  }

  Path _renderLimitLines = Path();
  List<double> _renderLimitLinesBuffer = List(2);
  Rect _limitLineClippingRect = Rect.zero;

  // ignore: unnecessary_getters_setters
  Rect get limitLineClippingRect => _limitLineClippingRect;

  // ignore: unnecessary_getters_setters
  set limitLineClippingRect(Rect value) {
    _limitLineClippingRect = value;
  }

  /// Draws the LimitLines associated with this axis to the screen.
  ///
  /// @param c
  @override
  void renderLimitLines(Canvas c) {
    List<LimitLine> limitLines = _yAxis.getLimitLines();

    if (limitLines == null || limitLines.length <= 0) return;

    List<double> pts = _renderLimitLinesBuffer;
    pts[0] = 0;
    pts[1] = 0;
    Path limitLinePath = _renderLimitLines;
    limitLinePath.reset();

    for (int i = 0; i < limitLines.length; i++) {
      LimitLine l = limitLines[i];

      if (!l.enabled) continue;

      c.save();
      _limitLineClippingRect = Rect.fromLTRB(
          viewPortHandler.getContentRect().left,
          viewPortHandler.getContentRect().top,
          viewPortHandler.getContentRect().right + l.lineWidth,
          viewPortHandler.getContentRect().bottom + l.lineWidth);
      c.clipRect(_limitLineClippingRect);

      limitLinePaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.lineWidth
        ..color = l.lineColor;

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
        TextPainter painter = PainterUtils.create(
            null, label, l.textColor, l.textSize,
            fontWeight: l.typeface?.fontWeight,
            fontFamily: l.typeface?.fontFamily);
        final double labelLineHeight =
            Utils.calcTextHeight(painter, label).toDouble();
        double xOffset = Utils.convertDpToPixel(4) + l.xOffset;
        double yOffset = l.lineWidth + labelLineHeight + l.yOffset;
        painter.layout();
        final LimitLabelPosition position = l.labelPosition;
        if (position == LimitLabelPosition.RIGHT_TOP) {
          var offset = Offset(
              viewPortHandler.contentRight() - xOffset - painter.width,
              pts[1] - yOffset + labelLineHeight - painter.height);
          CanvasUtils.renderLimitLabelBackground(c, painter, offset, l);
          painter.paint(c, offset);
        } else if (position == LimitLabelPosition.RIGHT_BOTTOM) {
          var offset = Offset(
              viewPortHandler.contentRight() - xOffset - painter.width,
              pts[1] + yOffset - painter.height);
          CanvasUtils.renderLimitLabelBackground(c, painter, offset, l);
          painter.paint(c, offset);
        } else if (position == LimitLabelPosition.RIGHT_CENTER) {
          var offset = Offset(
              viewPortHandler.contentRight() - xOffset - painter.width,
              pts[1] - (l.lineWidth + labelLineHeight) / 2);
          CanvasUtils.renderLimitLabelBackground(c, painter, offset, l);
          painter.paint(c, offset);
        } else if (position == LimitLabelPosition.LEFT_CENTER) {
          var offset = Offset(viewPortHandler.contentLeft() + xOffset,
              pts[1] - (l.lineWidth + labelLineHeight) / 2);
          CanvasUtils.renderLimitLabelBackground(c, painter, offset, l);
          painter.paint(c, offset);
        } else if (position == LimitLabelPosition.LEFT_TOP) {
          var offset = Offset(viewPortHandler.contentLeft() + xOffset,
              pts[1] - yOffset + labelLineHeight - painter.height);
          CanvasUtils.renderLimitLabelBackground(c, painter, offset, l);
          painter.paint(c, offset);
        } else {
          var offset = Offset(viewPortHandler.offsetLeft() + xOffset,
              pts[1] + yOffset - painter.height);
          CanvasUtils.renderLimitLabelBackground(c, painter, offset, l);
          painter.paint(c, offset);
        }
      }

      c.restore();
    }
  }

  // ignore: unnecessary_getters_setters
  Rect get gridClippingRect => _gridClippingRect;

  // ignore: unnecessary_getters_setters
  set gridClippingRect(Rect value) {
    _gridClippingRect = value;
  }

  // ignore: unnecessary_getters_setters
  Rect get zeroLineClippingRect => _zeroLineClippingRect;

  // ignore: unnecessary_getters_setters
  set zeroLineClippingRect(Rect value) {
    _zeroLineClippingRect = value;
  }
}
