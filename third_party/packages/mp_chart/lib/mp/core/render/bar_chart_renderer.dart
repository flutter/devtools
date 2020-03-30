import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/buffer/bar_buffer.dart';
import 'package:mp_chart/mp/core/color/gradient_color.dart';
import 'package:mp_chart/mp/core/data/bar_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/bar_data_provider.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/range.dart';
import 'package:mp_chart/mp/core/render/bar_line_scatter_candle_bubble_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:mp_chart/mp/core/view_port.dart';

class BarChartRenderer extends BarLineScatterCandleBubbleRenderer {
  BarDataProvider _provider;

  /// the rect object that is used for drawing the bars
  Rect _barRect = Rect.zero;

  List<BarBuffer> _barBuffers;

  Paint _shadowPaint;
  Paint _barBorderPaint;

  BarChartRenderer(
      BarDataProvider chart, Animator animator, ViewPortHandler viewPortHandler)
      : super(animator, viewPortHandler) {
    this._provider = chart;

    highlightPaint = Paint()
      ..isAntiAlias = true
      ..color = Color.fromARGB(120, 0, 0, 0)
      ..style = PaintingStyle.fill;

    _shadowPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    _barBorderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
  }

  set barRect(Rect value) {
    _barRect = value;
  }

  // ignore: unnecessary_getters_setters
  Paint get shadowPaint => _shadowPaint;

  // ignore: unnecessary_getters_setters
  set shadowPaint(Paint value) {
    _shadowPaint = value;
  }

  // ignore: unnecessary_getters_setters
  Paint get barBorderPaint => _barBorderPaint;

  // ignore: unnecessary_getters_setters
  set barBorderPaint(Paint value) {
    _barBorderPaint = value;
  }

  // ignore: unnecessary_getters_setters
  List<BarBuffer> get barBuffers => _barBuffers;

  // ignore: unnecessary_getters_setters
  set barBuffers(List<BarBuffer> value) {
    _barBuffers = value;
  }

  BarDataProvider get provider => _provider;

  @override
  void initBuffers() {
    BarData barData = _provider.getBarData();
    _barBuffers = List(barData.getDataSetCount());

    for (int i = 0; i < _barBuffers.length; i++) {
      IBarDataSet set = barData.getDataSetByIndex(i);
      _barBuffers[i] = BarBuffer(
          set.getEntryCount() * 4 * (set.isStacked() ? set.getStackSize() : 1),
          barData.getDataSetCount(),
          set.isStacked());
    }
  }

  @override
  void drawData(Canvas c) {
    BarData barData = _provider.getBarData();

    for (int i = 0; i < barData.getDataSetCount(); i++) {
      IBarDataSet set = barData.getDataSetByIndex(i);

      if (set.isVisible()) {
        drawDataSet(c, set, i);
      }
    }
  }

  void drawDataSet(Canvas c, IBarDataSet dataSet, int index) {
    Transformer trans = _provider.getTransformer(dataSet.getAxisDependency());

    _barBorderPaint..color = dataSet.getBarBorderColor();
    _barBorderPaint
      ..strokeWidth = Utils.convertDpToPixel(dataSet.getBarBorderWidth());

    final bool drawBorder = dataSet.getBarBorderWidth() > 0.0;

    double phaseX = animator.getPhaseX();
    double phaseY = animator.getPhaseY();

    // draw the bar shadow before the values
    if (_provider.isDrawBarShadowEnabled()) {
      _shadowPaint..color = dataSet.getBarShadowColor();

      BarData barData = _provider.getBarData();

      final double barWidth = barData.barWidth;
      final double barWidthHalf = barWidth / 2.0;
      double x;

      for (int i = 0,
              count = min((((dataSet.getEntryCount()) * phaseX).ceil()),
                  dataSet.getEntryCount());
          i < count;
          i++) {
        BarEntry e = dataSet.getEntryForIndex(i);

        x = e.x;

        _barShadowRectBuffer =
            Rect.fromLTRB(x - barWidthHalf, 0.0, x + barWidthHalf, 0.0);

        trans.rectValueToPixel(_barShadowRectBuffer);

        if (!viewPortHandler.isInBoundsLeft(_barShadowRectBuffer.right))
          continue;

        if (!viewPortHandler.isInBoundsRight(_barShadowRectBuffer.left)) break;

        _barShadowRectBuffer = Rect.fromLTRB(
            _barShadowRectBuffer.left,
            viewPortHandler.contentTop(),
            _barShadowRectBuffer.right,
            viewPortHandler.contentBottom());

        c.drawRect(_barShadowRectBuffer, _shadowPaint);
      }
    }

    // initialize the buffer
    BarBuffer buffer = _barBuffers[index];
    buffer.setPhases(phaseX, phaseY);
    buffer.dataSetIndex = (index);
    buffer.inverted = (_provider.isInverted(dataSet.getAxisDependency()));
    buffer.barWidth = (_provider.getBarData().barWidth);

    buffer.feed(dataSet);

    trans.pointValuesToPixel(buffer.buffer);

    final bool isSingleColor = dataSet.getColors().length == 1;

    if (isSingleColor) {
      renderPaint..color = dataSet.getColor1();
    }

    for (int j = 0; j < buffer.size(); j += 4) {
      if (!viewPortHandler.isInBoundsLeft(buffer.buffer[j + 2])) continue;

      if (!viewPortHandler.isInBoundsRight(buffer.buffer[j])) break;

      if (!isSingleColor) {
        // Set the color for the currently drawn value. If the index
        // is out of bounds, reuse colors.
        renderPaint..color = dataSet.getColor2(j ~/ 4);
      }

      if (dataSet.getGradientColor1() != null) {
        GradientColor gradientColor = dataSet.getGradientColor1();

        renderPaint
          ..shader = (LinearGradient(
                  colors: List()
                    ..add(gradientColor.startColor)
                    ..add(gradientColor.endColor),
                  tileMode: TileMode.mirror))
              .createShader(Rect.fromLTRB(
                  buffer.buffer[j],
                  buffer.buffer[j + 3],
                  buffer.buffer[j],
                  buffer.buffer[j + 1]));
      }

      if (dataSet.getGradientColors() != null) {
        renderPaint
          ..shader = (LinearGradient(
                  colors: List()
                    ..add(dataSet.getGradientColor2(j ~/ 4).startColor)
                    ..add(dataSet.getGradientColor2(j ~/ 4).endColor),
                  tileMode: TileMode.mirror))
              .createShader(Rect.fromLTRB(
                  buffer.buffer[j],
                  buffer.buffer[j + 3],
                  buffer.buffer[j],
                  buffer.buffer[j + 1]));
      }

      c.drawRect(
          Rect.fromLTRB(buffer.buffer[j], buffer.buffer[j + 1],
              buffer.buffer[j + 2], buffer.buffer[j + 3]),
          renderPaint);

      if (drawBorder) {
        c.drawRect(
            Rect.fromLTRB(buffer.buffer[j], buffer.buffer[j + 1],
                buffer.buffer[j + 2], buffer.buffer[j + 3]),
            _barBorderPaint);
      }
    }
  }

  Rect _barShadowRectBuffer = Rect.zero;

  void prepareBarHighlight(
      double x, double y1, double y2, double barWidthHalf, Transformer trans) {
    double left = x - barWidthHalf;
    double right = x + barWidthHalf;
    double top = y1;
    double bottom = y2;

    _barRect = trans.rectToPixelPhase(
        Rect.fromLTRB(left, top, right, bottom), animator.getPhaseY());
  }

  @override
  void drawValues(Canvas c) {
    // if values are drawn
    if (isDrawingValuesAllowed(_provider)) {
      List<IBarDataSet> dataSets = _provider.getBarData().dataSets;

      final double valueOffsetPlus = Utils.convertDpToPixel(4.5);
      double posOffset = 0.0;
      double negOffset = 0.0;
      bool drawValueAboveBar = _provider.isDrawValueAboveBarEnabled();

      for (int i = 0; i < _provider.getBarData().getDataSetCount(); i++) {
        IBarDataSet dataSet = dataSets[i];

        if (!shouldDrawValues(dataSet)) continue;

        // apply the text-styling defined by the DataSet
        applyValueTextStyle(dataSet);

        bool isInverted = _provider.isInverted(dataSet.getAxisDependency());

        // calculate the correct offset depending on the draw position of
        // the value
        double valueTextHeight =
            Utils.calcTextHeight(valuePaint, "8").toDouble();
        posOffset = (drawValueAboveBar
            ? -valueOffsetPlus
            : valueTextHeight + valueOffsetPlus);
        negOffset = (drawValueAboveBar
            ? valueTextHeight + valueOffsetPlus
            : -valueOffsetPlus);

        if (isInverted) {
          posOffset = -posOffset - valueTextHeight;
          negOffset = -negOffset - valueTextHeight;
        }

        // get the buffer
        BarBuffer buffer = _barBuffers[i];

        final double phaseY = animator.getPhaseY();

        ValueFormatter formatter = dataSet.getValueFormatter();

        MPPointF iconsOffset = MPPointF.getInstance3(dataSet.getIconsOffset());
        iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
        iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

        // if only single values are drawn (sum)
        if (!dataSet.isStacked()) {
          for (int j = 0;
              j < buffer.buffer.length * animator.getPhaseX();
              j += 4) {
            double x = (buffer.buffer[j] + buffer.buffer[j + 2]) / 2.0;

            if (!viewPortHandler.isInBoundsRight(x)) break;

            if (!viewPortHandler.isInBoundsY(buffer.buffer[j + 1]) ||
                !viewPortHandler.isInBoundsLeft(x)) continue;

            BarEntry entry = dataSet.getEntryForIndex(j ~/ 4);
            double val = entry.y;

            if (dataSet.isDrawValuesEnabled()) {
              drawValue(
                  c,
                  formatter.getBarLabel(entry),
                  x,
                  val >= 0
                      ? (buffer.buffer[j + 1] + posOffset)
                      : (buffer.buffer[j + 3] + negOffset),
                  dataSet.getValueTextColor2(j ~/ 4));
            }

            if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
              double px = x;
              double py = val >= 0
                  ? (buffer.buffer[j + 1] + posOffset)
                  : (buffer.buffer[j + 3] + negOffset);

              px += iconsOffset.x;
              py += iconsOffset.y;

              if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
                CanvasUtils.drawImage(
                    c, Offset(px, py), entry.mIcon, Size(15, 15), drawPaint);
              }
            }
          }

          // if we have stacks
        } else {
          Transformer trans =
              _provider.getTransformer(dataSet.getAxisDependency());

          int bufferIndex = 0;
          int index = 0;
          while (index < dataSet.getEntryCount() * animator.getPhaseX()) {
            BarEntry entry = dataSet.getEntryForIndex(index);

            List<double> vals = entry.yVals;
            double x =
                (buffer.buffer[bufferIndex] + buffer.buffer[bufferIndex + 2]) /
                    2.0;

            Color color = dataSet.getValueTextColor2(index);

            // we still draw stacked bars, but there is one
            // non-stacked
            // in between
            if (vals == null) {
              if (!viewPortHandler.isInBoundsRight(x)) break;

              if (!viewPortHandler
                      .isInBoundsY(buffer.buffer[bufferIndex + 1]) ||
                  !viewPortHandler.isInBoundsLeft(x)) continue;

              if (dataSet.isDrawValuesEnabled()) {
                drawValue(
                    c,
                    formatter.getBarLabel(entry),
                    x,
                    buffer.buffer[bufferIndex + 1] +
                        (entry.y >= 0 ? posOffset : negOffset),
                    color);
              }

              if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
                double px = x;
                double py = buffer.buffer[bufferIndex + 1] +
                    (entry.y >= 0 ? posOffset : negOffset);

                px += iconsOffset.x;
                py += iconsOffset.y;

                if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
                  CanvasUtils.drawImage(
                      c, Offset(px, py), entry.mIcon, Size(15, 15), drawPaint);
                }
              }

              // draw stack values
            } else {
              List<double> transformed = List(vals.length * 2);

              double posY = 0.0;
              double negY = -entry.negativeSum;

              for (int k = 0, idx = 0; k < transformed.length; k += 2, idx++) {
                double value = vals[idx];
                double y;

                if (value == 0.0 && (posY == 0.0 || negY == 0.0)) {
                  // Take care of the situation of a 0.0 value, which overlaps a non-zero bar
                  y = value;
                } else if (value >= 0.0) {
                  posY += value;
                  y = posY;
                } else {
                  y = negY;
                  negY -= value;
                }

                transformed[k + 1] = y * phaseY;
              }

              trans.pointValuesToPixel(transformed);

              for (int k = 0; k < transformed.length; k += 2) {
                final double val = vals[k ~/ 2];
                final bool drawBelow =
                    (val == 0.0 && negY == 0.0 && posY > 0.0) || val < 0.0;
                double y =
                    transformed[k + 1] + (drawBelow ? negOffset : posOffset);

                if (!viewPortHandler.isInBoundsRight(x)) break;

                if (!viewPortHandler.isInBoundsY(y) ||
                    !viewPortHandler.isInBoundsLeft(x)) continue;

                if (dataSet.isDrawValuesEnabled()) {
                  drawValue(
                      c, formatter.getBarStackedLabel(val, entry), x, y, color);
                }

                if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
                  CanvasUtils.drawImage(
                      c,
                      Offset(x + iconsOffset.x, y + iconsOffset.y),
                      entry.mIcon,
                      Size(15, 15),
                      drawPaint);
                }
              }
            }

            bufferIndex =
                vals == null ? bufferIndex + 4 : bufferIndex + 4 * vals.length;
            index++;
          }
        }

        MPPointF.recycleInstance(iconsOffset);
      }
    }
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
  void drawHighlighted(Canvas c, List<Highlight> indices) {
    BarData barData = _provider.getBarData();

    for (Highlight high in indices) {
      IBarDataSet set = barData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled()) continue;

      BarEntry e = set.getEntryForXValue2(high.x, high.y);

      if (!isInBoundsX(e, set)) continue;

      Transformer trans = _provider.getTransformer(set.getAxisDependency());

      var color = set.getHighLightColor();
      highlightPaint.color = Color.fromARGB(
          set.getHighLightAlpha(), color.red, color.green, color.blue);

      bool isStack = (high.stackIndex >= 0 && e.isStacked()) ? true : false;

      double y1;
      double y2;

      if (isStack) {
        if (_provider.isHighlightFullBarEnabled()) {
          y1 = e.positiveSum;
          y2 = -e.negativeSum;
        } else {
          Range range = e.ranges[high.stackIndex];

          y1 = range.from;
          y2 = range.to;
        }
      } else {
        y1 = e.y;
        y2 = 0.0;
      }

      prepareBarHighlight(e.x, y1, y2, barData.barWidth / 2.0, trans);

      setHighlightDrawPos(high, _barRect);
      c.drawRect(_barRect, highlightPaint);
    }
  }

  /// Sets the drawing position of the highlight object based on the riven bar-rect.
  /// @param high
  void setHighlightDrawPos(Highlight high, Rect bar) {
    high.setDraw(bar.center.dx, bar.top);
  }

  @override
  void drawExtras(Canvas c) {}
}
