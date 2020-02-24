import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/buffer/bar_buffer.dart';
import 'package:mp_chart/mp/core/buffer/horizontal_bar_buffer.dart';
import 'package:mp_chart/mp/core/data/bar_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/bar_data_provider.dart';
import 'package:mp_chart/mp/core/data_provider/chart_interface.dart';
import 'package:mp_chart/mp/core/entry/bar_entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/render/bar_chart_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class HorizontalBarChartRenderer extends BarChartRenderer {
  HorizontalBarChartRenderer(
      BarDataProvider chart, Animator animator, ViewPortHandler viewPortHandler)
      : super(chart, animator, viewPortHandler);

  @override
  void initBuffers() {
    BarData barData = provider.getBarData();
    barBuffers = List(barData.getDataSetCount());

    for (int i = 0; i < barBuffers.length; i++) {
      IBarDataSet set = barData.getDataSetByIndex(i);
      barBuffers[i] = HorizontalBarBuffer(
          set.getEntryCount() * 4 * (set.isStacked() ? set.getStackSize() : 1),
          barData.getDataSetCount(),
          set.isStacked());
    }
  }

  Rect mBarShadowRectBuffer = Rect.zero;

  @override
  void drawDataSet(Canvas c, IBarDataSet dataSet, int index) {
    Transformer trans = provider.getTransformer(dataSet.getAxisDependency());

    barBorderPaint
      ..color = dataSet.getBarBorderColor()
      ..strokeWidth = Utils.convertDpToPixel(dataSet.getBarBorderWidth());

    final bool drawBorder = dataSet.getBarBorderWidth() > 0.0;

    double phaseX = animator.getPhaseX();
    double phaseY = animator.getPhaseY();

    // draw the bar shadow before the values
    if (provider.isDrawBarShadowEnabled()) {
      shadowPaint..color = dataSet.getBarShadowColor();

      BarData barData = provider.getBarData();

      final double barWidth = barData.barWidth;
      final double barWidthHalf = barWidth / 2.0;
      double x;

      for (int i = 0,
              count = min(((dataSet.getEntryCount()) * phaseX).ceil(),
                  dataSet.getEntryCount());
          i < count;
          i++) {
        BarEntry e = dataSet.getEntryForIndex(i);

        x = e.x;

        mBarShadowRectBuffer = Rect.fromLTRB(mBarShadowRectBuffer.left,
            x - barWidthHalf, mBarShadowRectBuffer.right, x + barWidthHalf);

        trans.rectValueToPixel(mBarShadowRectBuffer);

        if (!viewPortHandler.isInBoundsTop(mBarShadowRectBuffer.bottom))
          continue;

        if (!viewPortHandler.isInBoundsBottom(mBarShadowRectBuffer.top)) break;

        mBarShadowRectBuffer = Rect.fromLTRB(
            viewPortHandler.contentLeft(),
            mBarShadowRectBuffer.top,
            viewPortHandler.contentRight(),
            mBarShadowRectBuffer.bottom);

        c.drawRect(mBarShadowRectBuffer, shadowPaint);
      }
    }

    // initialize the buffer
    BarBuffer buffer = barBuffers[index];
    buffer.setPhases(phaseX, phaseY);
    buffer.dataSetIndex = (index);
    buffer.inverted = (provider.isInverted(dataSet.getAxisDependency()));
    buffer.barWidth = (provider.getBarData().barWidth);

    buffer.feed(dataSet);

    trans.pointValuesToPixel(buffer.buffer);

    final bool isSingleColor = dataSet.getColors().length == 1;

    if (isSingleColor) {
      renderPaint..color = dataSet.getColor1();
    }

    for (int j = 0; j < buffer.size(); j += 4) {
      if (!viewPortHandler.isInBoundsTop(buffer.buffer[j + 3])) break;

      if (!viewPortHandler.isInBoundsBottom(buffer.buffer[j + 1])) continue;

      if (!isSingleColor) {
        // Set the color for the currently drawn value. If the index
        // is out of bounds, reuse colors.
        renderPaint..color = (dataSet.getColor2(j ~/ 4));
      }

      c.drawRect(
          Rect.fromLTRB(buffer.buffer[j], buffer.buffer[j + 1],
              buffer.buffer[j + 2], buffer.buffer[j + 3]),
          renderPaint);

      if (drawBorder) {
        c.drawRect(
            Rect.fromLTRB(buffer.buffer[j], buffer.buffer[j + 1],
                buffer.buffer[j + 2], buffer.buffer[j + 3]),
            barBorderPaint);
      }
    }
  }

  @override
  void drawValues(Canvas c) {
    // if values are drawn
    if (!isDrawingValuesAllowed(provider)) return;

    List<IBarDataSet> dataSets = provider.getBarData().dataSets;

    final double valueOffsetPlus = Utils.convertDpToPixel(5);
    double posOffset = 0;
    double negOffset = 0;
    final bool drawValueAboveBar = provider.isDrawValueAboveBarEnabled();

    for (int i = 0; i < provider.getBarData().getDataSetCount(); i++) {
      IBarDataSet dataSet = dataSets[i];

      if (!shouldDrawValues(dataSet)) continue;

      bool isInverted = provider.isInverted(dataSet.getAxisDependency());

      // apply the text-styling defined by the DataSet
      applyValueTextStyle(dataSet);

      ValueFormatter formatter = dataSet.getValueFormatter();

      // get the buffer
      BarBuffer buffer = barBuffers[i];

      final double phaseY = animator.getPhaseY();

      MPPointF iconsOffset = MPPointF.getInstance3(dataSet.getIconsOffset());
      iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
      iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

      // if only single values are drawn (sum)
      if (!dataSet.isStacked()) {
        for (int j = 0;
            j < buffer.buffer.length * animator.getPhaseX();
            j += 4) {
          double y = (buffer.buffer[j + 1] + buffer.buffer[j + 3]) / 2;

          if (!viewPortHandler.isInBoundsTop(buffer.buffer[j + 1])) break;

          if (!viewPortHandler.isInBoundsX(buffer.buffer[j])) continue;

          if (!viewPortHandler.isInBoundsBottom(buffer.buffer[j + 1])) continue;

          BarEntry entry = dataSet.getEntryForIndex(j ~/ 4);
          double val = entry.y;
          String formattedValue = formatter.getBarLabel(entry);

          // calculate the correct offset depending on the draw position of the value
          double valueTextWidth =
              Utils.calcTextWidth(valuePaint, formattedValue).toDouble();
          posOffset = (drawValueAboveBar
              ? valueOffsetPlus
              : -(valueTextWidth + valueOffsetPlus));
          negOffset = (drawValueAboveBar
              ? -(valueTextWidth + valueOffsetPlus)
              : valueOffsetPlus);

          if (isInverted) {
            posOffset = -posOffset - valueTextWidth;
            negOffset = -negOffset - valueTextWidth;
          }

          if (dataSet.isDrawValuesEnabled()) {
            drawValue(
                c,
                formattedValue,
                buffer.buffer[j + 2] + (val >= 0 ? posOffset : negOffset),
                y,
                dataSet.getValueTextColor2(j ~/ 2));
          }
          if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
            double px =
                buffer.buffer[j + 2] + (val >= 0 ? posOffset : negOffset);
            double py = y;

            px += iconsOffset.x;
            py += iconsOffset.y;

            CanvasUtils.drawImage(
                c, Offset(px, py), entry.mIcon, Size(15, 15), drawPaint);
          }
        }

        // if each value of a potential stack should be drawn
      } else {
        Transformer trans =
            provider.getTransformer(dataSet.getAxisDependency());

        int bufferIndex = 0;
        int index = 0;

        while (index < dataSet.getEntryCount() * animator.getPhaseX()) {
          BarEntry entry = dataSet.getEntryForIndex(index);

          Color color = dataSet.getValueTextColor2(index);
          List<double> vals = entry.yVals;

          // we still draw stacked bars, but there is one
          // non-stacked
          // in between
          if (vals == null) {
            if (!viewPortHandler.isInBoundsTop(buffer.buffer[bufferIndex + 1]))
              break;

            if (!viewPortHandler.isInBoundsX(buffer.buffer[bufferIndex]))
              continue;

            if (!viewPortHandler
                .isInBoundsBottom(buffer.buffer[bufferIndex + 1])) continue;

            String formattedValue = formatter.getBarLabel(entry);

            // calculate the correct offset depending on the draw position of the value
            double valueTextWidth =
                Utils.calcTextWidth(valuePaint, formattedValue).toDouble();
            posOffset = (drawValueAboveBar
                ? valueOffsetPlus
                : -(valueTextWidth + valueOffsetPlus));
            negOffset = (drawValueAboveBar
                ? -(valueTextWidth + valueOffsetPlus)
                : valueOffsetPlus);

            if (isInverted) {
              posOffset = -posOffset - valueTextWidth;
              negOffset = -negOffset - valueTextWidth;
            }

            if (dataSet.isDrawValuesEnabled()) {
              drawValue(
                  c,
                  formattedValue,
                  buffer.buffer[bufferIndex + 2] +
                      (entry.y >= 0 ? posOffset : negOffset),
                  buffer.buffer[bufferIndex + 1],
                  color);
            }
            if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
              double px = buffer.buffer[bufferIndex + 2] +
                  (entry.y >= 0 ? posOffset : negOffset);
              double py = buffer.buffer[bufferIndex + 1];

              px += iconsOffset.x;
              py += iconsOffset.y;

              CanvasUtils.drawImage(
                  c, Offset(px, py), entry.mIcon, Size(15, 15), drawPaint);
            }
          } else {
            List<double> transformed = List(vals.length * 2);

            double posY = 0;
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

              transformed[k] = y * phaseY;
            }

            trans.pointValuesToPixel(transformed);

            for (int k = 0; k < transformed.length; k += 2) {
              final double val = vals[k ~/ 2];
              String formattedValue = formatter.getBarStackedLabel(val, entry);

              // calculate the correct offset depending on the draw position of the value
              double valueTextWidth =
                  Utils.calcTextWidth(valuePaint, formattedValue).toDouble();
              posOffset = (drawValueAboveBar
                  ? valueOffsetPlus
                  : -(valueTextWidth + valueOffsetPlus));
              negOffset = (drawValueAboveBar
                  ? -(valueTextWidth + valueOffsetPlus)
                  : valueOffsetPlus);

              if (isInverted) {
                posOffset = -posOffset - valueTextWidth;
                negOffset = -negOffset - valueTextWidth;
              }

              final bool drawBelow =
                  (val == 0.0 && negY == 0.0 && posY > 0.0) || val < 0.0;

              double x = transformed[k] + (drawBelow ? negOffset : posOffset);
              double y = (buffer.buffer[bufferIndex + 1] +
                      buffer.buffer[bufferIndex + 3]) /
                  2;

              if (!viewPortHandler.isInBoundsTop(y)) break;

              if (!viewPortHandler.isInBoundsX(x)) continue;

              if (!viewPortHandler.isInBoundsBottom(y)) continue;

              if (dataSet.isDrawValuesEnabled()) {
                drawValue(c, formattedValue, x, y, color);
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
    valuePaint.paint(c, Offset(x, y - valuePaint.height / 2));
  }

  @override
  void prepareBarHighlight(
      double x, double y1, double y2, double barWidthHalf, Transformer trans) {
    double top = x - barWidthHalf;
    double bottom = x + barWidthHalf;
    double left = y1;
    double right = y2;

    barRect = trans.rectToPixelPhaseHorizontal(
        Rect.fromLTRB(left, top, right, bottom), animator.getPhaseY());
  }

  @override
  void setHighlightDrawPos(Highlight high, Rect bar) {
    high.setDraw(bar.center.dy, bar.right);
  }

  @override
  bool isDrawingValuesAllowed(ChartInterface chart) {
    return chart.getData().getEntryCount() <
        chart.getMaxVisibleCount() * viewPortHandler.getScaleY();
  }
}
