import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data/bubble_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bubble_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/bubble_data_provider.dart';
import 'package:mp_chart/mp/core/entry/bubble_entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/render/bar_line_scatter_candle_bubble_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class BubbleChartRenderer extends BarLineScatterCandleBubbleRenderer {
  BubbleDataProvider _provider;

  BubbleChartRenderer(BubbleDataProvider chart, Animator animator,
      ViewPortHandler viewPortHandler)
      : super(animator, viewPortHandler) {
    _provider = chart;

    renderPaint..style = PaintingStyle.fill;

    highlightPaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = Utils.convertDpToPixel(1.5);
  }

  BubbleDataProvider get provider => _provider;

  @override
  void initBuffers() {}

  @override
  void drawData(Canvas c) {
    BubbleData bubbleData = _provider.getBubbleData();

    for (IBubbleDataSet set in bubbleData.dataSets) {
      if (set.isVisible()) drawDataSet(c, set);
    }
  }

  List<double> sizeBuffer = List(4);
  List<double> pointBuffer = List(2);

  double getShapeSize(
      double entrySize, double maxSize, double reference, bool normalizeSize) {
    final double factor = normalizeSize
        ? ((maxSize == 0) ? 1 : sqrt(entrySize / maxSize))
        : entrySize;
    final double shapeSize = reference * factor;
    return shapeSize;
  }

  void drawDataSet(Canvas c, IBubbleDataSet dataSet) {
    if (dataSet.getEntryCount() < 1) return;

    Transformer trans = _provider.getTransformer(dataSet.getAxisDependency());

    double phaseY = animator.getPhaseY();

    xBounds.set(_provider, dataSet);

    sizeBuffer[0] = 0;
    sizeBuffer[2] = 1;

    trans.pointValuesToPixel(sizeBuffer);

    bool normalizeSize = dataSet.isNormalizeSizeEnabled();

    // calcualte the full width of 1 step on the x-axis
    final double maxBubbleWidth = (sizeBuffer[2] - sizeBuffer[0]).abs();
    final double maxBubbleHeight =
        (viewPortHandler.contentBottom() - viewPortHandler.contentTop()).abs();
    final double referenceSize = min(maxBubbleHeight, maxBubbleWidth);

    for (int j = xBounds.min; j <= xBounds.range + xBounds.min; j++) {
      final BubbleEntry entry = dataSet.getEntryForIndex(j);

      pointBuffer[0] = entry.x;
      pointBuffer[1] = (entry.y) * phaseY;
      trans.pointValuesToPixel(pointBuffer);

      double shapeHalf = getShapeSize(
              entry.size, dataSet.getMaxSize(), referenceSize, normalizeSize) /
          2;

      if (!viewPortHandler.isInBoundsTop(pointBuffer[1] + shapeHalf) ||
          !viewPortHandler.isInBoundsBottom(pointBuffer[1] - shapeHalf))
        continue;

      if (!viewPortHandler.isInBoundsLeft(pointBuffer[0] + shapeHalf)) continue;

      if (!viewPortHandler.isInBoundsRight(pointBuffer[0] - shapeHalf)) break;

      final Color color = dataSet.getColor2(entry.x.toInt());

      renderPaint.color = color;
      c.drawCircle(
          Offset(pointBuffer[0], pointBuffer[1]), shapeHalf, renderPaint);
    }
  }

  @override
  void drawValues(Canvas c) {
    BubbleData bubbleData = _provider.getBubbleData();

    if (bubbleData == null) return;

    // if values are drawn
    if (isDrawingValuesAllowed(_provider)) {
      final List<IBubbleDataSet> dataSets = bubbleData.dataSets;

      double lineHeight = Utils.calcTextHeight(valuePaint, "1").toDouble();

      for (int i = 0; i < dataSets.length; i++) {
        IBubbleDataSet dataSet = dataSets[i];

        if (!shouldDrawValues(dataSet) || dataSet.getEntryCount() < 1) continue;

        // apply the text-styling defined by the DataSet
        applyValueTextStyle(dataSet);

        final double phaseX = max(0.0, min(1.0, animator.getPhaseX()));
        final double phaseY = animator.getPhaseY();

        xBounds.set(_provider, dataSet);

        List<double> positions = _provider
            .getTransformer(dataSet.getAxisDependency())
            .generateTransformedValuesBubble(
                dataSet, phaseY, xBounds.min, xBounds.max);

        final double alpha = phaseX == 1 ? phaseY : phaseX;

        ValueFormatter formatter = dataSet.getValueFormatter();

        MPPointF iconsOffset = MPPointF.getInstance3(dataSet.getIconsOffset());
        iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
        iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

        for (int j = 0; j < positions.length; j += 2) {
          Color valueTextColor =
              dataSet.getValueTextColor2(j ~/ 2 + xBounds.min);
          valueTextColor = Color.fromARGB((255.0 * alpha).round(),
              valueTextColor.red, valueTextColor.green, valueTextColor.blue);

          double x = positions[j];
          double y = positions[j + 1];

          if (!viewPortHandler.isInBoundsRight(x)) break;

          if ((!viewPortHandler.isInBoundsLeft(x) ||
              !viewPortHandler.isInBoundsY(y))) continue;

          BubbleEntry entry = dataSet.getEntryForIndex(j ~/ 2 + xBounds.min);

          if (dataSet.isDrawValuesEnabled()) {
            drawValue(c, formatter.getBubbleLabel(entry), x,
                y + (0.5 * lineHeight), valueTextColor);
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
            ? Utils.convertDpToPixel(13)
            : valuePaint.text.style.fontSize);
    valuePaint.layout();
    valuePaint.paint(
        c, Offset(x - valuePaint.width / 2, y - valuePaint.height));
  }

  @override
  void drawExtras(Canvas c) {}

  @override
  void drawHighlighted(Canvas c, List<Highlight> indices) {
    BubbleData bubbleData = _provider.getBubbleData();

    double phaseY = animator.getPhaseY();

    for (Highlight high in indices) {
      IBubbleDataSet set = bubbleData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled()) continue;

      final BubbleEntry entry = set.getEntryForXValue2(high.x, high.y);

      if (entry.y != high.y) continue;

      if (!isInBoundsX(entry, set)) continue;

      Transformer trans = _provider.getTransformer(set.getAxisDependency());

      sizeBuffer[0] = 0;
      sizeBuffer[2] = 1;

      trans.pointValuesToPixel(sizeBuffer);

      bool normalizeSize = set.isNormalizeSizeEnabled();

      // calcualte the full width of 1 step on the x-axis
      final double maxBubbleWidth = (sizeBuffer[2] - sizeBuffer[0]).abs();
      final double maxBubbleHeight =
          (viewPortHandler.contentBottom() - viewPortHandler.contentTop())
              .abs();
      final double referenceSize = min(maxBubbleHeight, maxBubbleWidth);

      pointBuffer[0] = entry.x;
      pointBuffer[1] = (entry.y) * phaseY;
      trans.pointValuesToPixel(pointBuffer);

      high.setDraw(pointBuffer[0], pointBuffer[1]);

      double shapeHalf = getShapeSize(
              entry.size, set.getMaxSize(), referenceSize, normalizeSize) /
          2;

      if (!viewPortHandler.isInBoundsTop(pointBuffer[1] + shapeHalf) ||
          !viewPortHandler.isInBoundsBottom(pointBuffer[1] - shapeHalf))
        continue;

      if (!viewPortHandler.isInBoundsLeft(pointBuffer[0] + shapeHalf)) continue;

      if (!viewPortHandler.isInBoundsRight(pointBuffer[0] - shapeHalf)) break;

      final Color originalColor = set.getColor2(entry.x.toInt());

      var hsv = HSVColor.fromColor(originalColor);
      var color = hsv.toColor();

      highlightPaint
        ..color = color
        ..strokeWidth = set.getHighlightCircleWidth();
      c.drawCircle(
          Offset(pointBuffer[0], pointBuffer[1]), shapeHalf, highlightPaint);
    }
  }
}
