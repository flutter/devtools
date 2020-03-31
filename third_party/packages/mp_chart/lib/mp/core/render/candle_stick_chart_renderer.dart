import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/animator.dart';
import 'package:mp_chart/mp/core/data/candle_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_candle_data_set.dart';
import 'package:mp_chart/mp/core/data_provider/candle_data_provider.dart';
import 'package:mp_chart/mp/core/entry/candle_entry.dart';
import 'package:mp_chart/mp/core/highlight/highlight.dart';
import 'package:mp_chart/mp/core/render/line_scatter_candle_radar_renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/canvas_utils.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/value_formatter/value_formatter.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class CandleStickChartRenderer extends LineScatterCandleRadarRenderer {
  CandleDataProvider _porvider;

  List<double> _shadowBuffers = List(8);
  List<double> _bodyBuffers = List(4);
  List<double> _rangeBuffers = List(4);
  List<double> _openBuffers = List(4);
  List<double> _closeBuffers = List(4);

  CandleStickChartRenderer(CandleDataProvider chart, Animator animator,
      ViewPortHandler viewPortHandler)
      : super(animator, viewPortHandler) {
    _porvider = chart;
  }

  CandleDataProvider get porvider => _porvider;

  @override
  void initBuffers() {}

  @override
  void drawData(Canvas c) {
    CandleData candleData = _porvider.getCandleData();

    for (ICandleDataSet set in candleData.dataSets) {
      if (set.isVisible()) drawDataSet(c, set);
    }
  }

  void drawDataSet(Canvas c, ICandleDataSet dataSet) {
    Transformer trans = _porvider.getTransformer(dataSet.getAxisDependency());

    double phaseY = animator.getPhaseY();
    double barSpace = dataSet.getBarSpace();
    bool showCandleBar = dataSet.getShowCandleBar();

    xBounds.set(_porvider, dataSet);

    renderPaint.strokeWidth = dataSet.getShadowWidth();

    // draw the body
    for (int j = xBounds.min; j <= xBounds.range + xBounds.min; j++) {
      // get the entry
      CandleEntry e = dataSet.getEntryForIndex(j);

      if (e == null) continue;

      final double xPos = e.x;

      final double open = e.open;
      final double close = e.close;
      final double high = e.shadowHigh;
      final double low = e.shadowLow;

      if (showCandleBar) {
        // calculate the shadow

        _shadowBuffers[0] = xPos;
        _shadowBuffers[2] = xPos;
        _shadowBuffers[4] = xPos;
        _shadowBuffers[6] = xPos;

        if (open > close) {
          _shadowBuffers[1] = high * phaseY;
          _shadowBuffers[3] = open * phaseY;
          _shadowBuffers[5] = low * phaseY;
          _shadowBuffers[7] = close * phaseY;
        } else if (open < close) {
          _shadowBuffers[1] = high * phaseY;
          _shadowBuffers[3] = close * phaseY;
          _shadowBuffers[5] = low * phaseY;
          _shadowBuffers[7] = open * phaseY;
        } else {
          _shadowBuffers[1] = high * phaseY;
          _shadowBuffers[3] = open * phaseY;
          _shadowBuffers[5] = low * phaseY;
          _shadowBuffers[7] = _shadowBuffers[3];
        }

        trans.pointValuesToPixel(_shadowBuffers);

        // draw the shadows

        if (dataSet.getShadowColorSameAsCandle()) {
          if (open > close)
            renderPaint.color =
                dataSet.getDecreasingColor() == ColorUtils.COLOR_NONE
                    ? dataSet.getColor2(j)
                    : dataSet.getDecreasingColor();
          else if (open < close)
            renderPaint.color =
                dataSet.getIncreasingColor() == ColorUtils.COLOR_NONE
                    ? dataSet.getColor2(j)
                    : dataSet.getIncreasingColor();
          else
            renderPaint.color =
                dataSet.getNeutralColor() == ColorUtils.COLOR_NONE
                    ? dataSet.getColor2(j)
                    : dataSet.getNeutralColor();
        } else {
          renderPaint.color = dataSet.getShadowColor() == ColorUtils.COLOR_NONE
              ? dataSet.getColor2(j)
              : dataSet.getShadowColor();
        }

        renderPaint.style = PaintingStyle.stroke;

        CanvasUtils.drawLines(
            c, _shadowBuffers, 0, _shadowBuffers.length, renderPaint);

        // calculate the body

        _bodyBuffers[0] = xPos - 0.5 + barSpace;
        _bodyBuffers[1] = close * phaseY;
        _bodyBuffers[2] = (xPos + 0.5 - barSpace);
        _bodyBuffers[3] = open * phaseY;

        trans.pointValuesToPixel(_bodyBuffers);

        // draw body differently for increasing and decreasing entry
        if (open > close) {
          // decreasing

          if (dataSet.getDecreasingColor() == ColorUtils.COLOR_NONE) {
            renderPaint.color = dataSet.getColor2(j);
          } else {
            renderPaint.color = dataSet.getDecreasingColor();
          }

          renderPaint.style = PaintingStyle.fill;

          c.drawRect(
              Rect.fromLTRB(_bodyBuffers[0], _bodyBuffers[3], _bodyBuffers[2],
                  _bodyBuffers[1]),
              renderPaint);
        } else if (open < close) {
          if (dataSet.getIncreasingColor() == ColorUtils.COLOR_NONE) {
            renderPaint.color = dataSet.getColor2(j);
          } else {
            renderPaint.color = dataSet.getIncreasingColor();
          }

          renderPaint.style = PaintingStyle.fill;

          c.drawRect(
              Rect.fromLTRB(_bodyBuffers[0], _bodyBuffers[1], _bodyBuffers[2],
                  _bodyBuffers[3]),
              renderPaint);
        } else {
          // equal values

          if (dataSet.getNeutralColor() == ColorUtils.COLOR_NONE) {
            renderPaint.color = dataSet.getColor2(j);
          } else {
            renderPaint.color = dataSet.getNeutralColor();
          }

          c.drawLine(Offset(_bodyBuffers[0], _bodyBuffers[1]),
              Offset(_bodyBuffers[2], _bodyBuffers[3]), renderPaint);
        }
      } else {
        _rangeBuffers[0] = xPos;
        _rangeBuffers[1] = high * phaseY;
        _rangeBuffers[2] = xPos;
        _rangeBuffers[3] = low * phaseY;

        _openBuffers[0] = xPos - 0.5 + barSpace;
        _openBuffers[1] = open * phaseY;
        _openBuffers[2] = xPos;
        _openBuffers[3] = open * phaseY;

        _closeBuffers[0] = xPos + 0.5 - barSpace;
        _closeBuffers[1] = close * phaseY;
        _closeBuffers[2] = xPos;
        _closeBuffers[3] = close * phaseY;

        trans.pointValuesToPixel(_rangeBuffers);
        trans.pointValuesToPixel(_openBuffers);
        trans.pointValuesToPixel(_closeBuffers);

        // draw the ranges
        Color barColor;

        if (open > close)
          barColor = dataSet.getDecreasingColor() == ColorUtils.COLOR_NONE
              ? dataSet.getColor2(j)
              : dataSet.getDecreasingColor();
        else if (open < close)
          barColor = dataSet.getIncreasingColor() == ColorUtils.COLOR_NONE
              ? dataSet.getColor2(j)
              : dataSet.getIncreasingColor();
        else
          barColor = dataSet.getNeutralColor() == ColorUtils.COLOR_NONE
              ? dataSet.getColor2(j)
              : dataSet.getNeutralColor();

        renderPaint.color = barColor;
        c.drawLine(Offset(_rangeBuffers[0], _rangeBuffers[1]),
            Offset(_rangeBuffers[2], _rangeBuffers[3]), renderPaint);
        c.drawLine(Offset(_openBuffers[0], _openBuffers[1]),
            Offset(_openBuffers[2], _openBuffers[3]), renderPaint);
        c.drawLine(Offset(_closeBuffers[0], _closeBuffers[1]),
            Offset(_closeBuffers[2], _closeBuffers[3]), renderPaint);
      }
    }
  }

  @override
  void drawValues(Canvas c) {
    // if values are drawn
    if (isDrawingValuesAllowed(_porvider)) {
      List<ICandleDataSet> dataSets = _porvider.getCandleData().dataSets;

      for (int i = 0; i < dataSets.length; i++) {
        ICandleDataSet dataSet = dataSets[i];

        if (!shouldDrawValues(dataSet) || dataSet.getEntryCount() < 1) continue;

        // apply the text-styling defined by the DataSet
        applyValueTextStyle(dataSet);

        Transformer trans =
            _porvider.getTransformer(dataSet.getAxisDependency());

        xBounds.set(_porvider, dataSet);

        List<double> positions = trans.generateTransformedValuesCandle(
            dataSet,
            animator.getPhaseX(),
            animator.getPhaseY(),
            xBounds.min,
            xBounds.max);

        double yOffset = Utils.convertDpToPixel(5);

        ValueFormatter formatter = dataSet.getValueFormatter();

        MPPointF iconsOffset = MPPointF.getInstance3(dataSet.getIconsOffset());
        iconsOffset.x = Utils.convertDpToPixel(iconsOffset.x);
        iconsOffset.y = Utils.convertDpToPixel(iconsOffset.y);

        for (int j = 0; j < positions.length; j += 2) {
          double x = positions[j];
          double y = positions[j + 1];

          if (!viewPortHandler.isInBoundsRight(x)) break;

          if (!viewPortHandler.isInBoundsLeft(x) ||
              !viewPortHandler.isInBoundsY(y)) continue;

          CandleEntry entry = dataSet.getEntryForIndex(j ~/ 2 + xBounds.min);

          if (dataSet.isDrawValuesEnabled()) {
            drawValue(c, formatter.getCandleLabel(entry), x, y - yOffset,
                dataSet.getValueTextColor2(j ~/ 2));
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
    CandleData candleData = _porvider.getCandleData();

    for (Highlight high in indices) {
      ICandleDataSet set = candleData.getDataSetByIndex(high.dataSetIndex);

      if (set == null || !set.isHighlightEnabled()) continue;

      CandleEntry e = set.getEntryForXValue2(high.x, high.y);

      if (!isInBoundsX(e, set)) continue;

      double lowValue = e.shadowLow * animator.getPhaseY();
      double highValue = e.shadowHigh * animator.getPhaseY();
      double y = (lowValue + highValue) / 2;

      MPPointD pix = _porvider
          .getTransformer(set.getAxisDependency())
          .getPixelForValues(e.x, y);

      high.setDraw(pix.x, pix.y);

      // draw the lines
      drawHighlightLines(c, pix.x, pix.y, set);
    }
  }
}
