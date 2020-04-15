import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data/scatter_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_scatter_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/scatter_data_provider.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/render/i_shape_renderer.dart';
import 'package:mp_chart/mp/core/render/line_scatter_candle_radar_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class ScatterChartRenderer extends LineScatterCandleRadarRenderer {
  ScatterDataProvider _provider;

  ScatterChartRenderer(ScatterDataProvider chart, Animator animator,
      ViewPortHandler viewPortHandler)
      : super(animator, viewPortHandler) {
    _provider = chart;
  }

  ScatterDataProvider get provider => _provider;

  @override
  void initBuffers() {}

  @override
  void drawData(Canvas c) {
    ScatterData scatterData = _provider.getScatterData();

    for (IScatterDataSet set in scatterData.dataSets) {
      if (set.isVisible()) drawDataSet(c, set);
    }
  }

  List<double> mPixelBuffer = List(2);

  void drawDataSet(Canvas c, IScatterDataSet dataSet) {
    if (dataSet.getEntryCount() < 1) return;

    Transformer trans = _provider.getTransformer(dataSet.getAxisDependency());

    double phaseY = animator.getPhaseY();

    IShapeRenderer renderer = dataSet.getShapeRenderer();
    if (renderer == null) {
      return;
    }

    int max = (min((dataSet.getEntryCount() * animator.getPhaseX()).ceil(),
        dataSet.getEntryCount()));

    for (int i = 0; i < max; i++) {
      Entry e = dataSet.getEntryForIndex(i);

      mPixelBuffer[0] = e.x;
      mPixelBuffer[1] = e.y * phaseY;

      trans.pointValuesToPixel(mPixelBuffer);

      if (!viewPortHandler.isInBoundsRight(mPixelBuffer[0])) break;

      if (!viewPortHandler.isInBoundsLeft(mPixelBuffer[0]) ||
          !viewPortHandler.isInBoundsY(mPixelBuffer[1])) continue;

      renderPaint.color = dataSet.getColor2(i ~/ 2);
      renderer.renderShape(c, dataSet, viewPortHandler, mPixelBuffer[0],
          mPixelBuffer[1], renderPaint);
    }
  }

  @override
  void drawValues(Canvas c) {
    // if values are drawn
    if (isDrawingValuesAllowed(_provider)) {
      List<IScatterDataSet> dataSets = _provider.getScatterData().dataSets;

      for (int i = 0; i < _provider.getScatterData().getDataSetCount(); i++) {
        IScatterDataSet dataSet = dataSets[i];

        if (!shouldDrawValues(dataSet) || dataSet.getEntryCount() < 1) continue;

        // apply the text-styling defined by the DataSet
        applyValueTextStyle(dataSet);

        xBounds.set(_provider, dataSet);

        List<double> positions = _provider
            .getTransformer(dataSet.getAxisDependency())
            .generateTransformedValuesScatter(dataSet, animator.getPhaseX(),
                animator.getPhaseY(), xBounds.min, xBounds.max);

        double shapeSize =
            Utils.convertDpToPixel(dataSet.getScatterShapeSize());

        ValueFormatter formatter = dataSet.getValueFormatter();

        MPPointF iconsOffset = MPPointF.getInstance3(dataSet.getIconsOffset());
        iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
        iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

        for (int j = 0; j < positions.length; j += 2) {
          if (!viewPortHandler.isInBoundsRight(positions[j])) break;

          // make sure the lines don't do shitty things outside bounds
          if ((!viewPortHandler.isInBoundsLeft(positions[j]) ||
              !viewPortHandler.isInBoundsY(positions[j + 1]))) continue;

          Entry entry = dataSet.getEntryForIndex(j ~/ 2 + xBounds.min);

          if (dataSet.isDrawValuesEnabled()) {
            drawValue(
                c,
                formatter.getPointLabel(entry),
                positions[j],
                positions[j + 1] - shapeSize,
                dataSet.getValueTextColor2(j ~/ 2 + xBounds.min));
          }

          if (entry.mIcon != null && dataSet.isDrawIconsEnabled()) {
            CanvasUtils.drawImage(
                c,
                Offset(positions[j] + iconsOffset.x,
                    positions[j + 1] + iconsOffset.y),
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
            ? Utils.convertDpToPixel(9)
            : valuePaint.text.style.fontSize);
    valuePaint.layout();
    valuePaint.paint(
        c, Offset(x - valuePaint.width / 2, y - valuePaint.height));
  }

  @override
  void drawExtras(Canvas c) {}

  @override
  void drawHighlighted(Canvas c, List<Highlight> indices) {
    ScatterData scatterData = _provider.getScatterData();

    for (Highlight high in indices) {
      IScatterDataSet set = scatterData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled()) continue;

      final Entry e = set.getEntryForXValue2(high.x, high.y);

      if (!isInBoundsX(e, set)) continue;

      MPPointD pix = _provider
          .getTransformer(set.getAxisDependency())
          .getPixelForValues(e.x, e.y * animator.getPhaseY());

      high.setDraw(pix.x, pix.y);

      // draw the lines
      drawHighlightLines(c, pix.x, pix.y, set);
    }
  }
}
