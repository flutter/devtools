import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/data/chart_data.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_bar_data_set.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_candle_data_set.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_data_set.dart';
import 'package:mp_chart/mp/core/data_interfaces/i_pie_data_set.dart';
import 'package:mp_chart/mp/core/enums/legend_direction.dart';
import 'package:mp_chart/mp/core/enums/legend_form.dart';
import 'package:mp_chart/mp/core/enums/legend_horizontal_alignment.dart';
import 'package:mp_chart/mp/core/enums/legend_orientation.dart';
import 'package:mp_chart/mp/core/enums/legend_vertical_alignment.dart';
import 'package:mp_chart/mp/core/legend/legend.dart';
import 'package:mp_chart/mp/core/legend/legend_entry.dart';
import 'package:mp_chart/mp/core/poolable/size.dart';
import 'package:mp_chart/mp/core/render/renderer.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';

class LegendRenderer extends Renderer {
  /// paint for the legend labels
  TextPainter _legendLabelPaint;

  /// paint used for the legend forms
  Paint _legendFormPaint;

  /// the legend object this renderer renders
  Legend _legend;

  LegendRenderer(ViewPortHandler viewPortHandler, Legend legend)
      : super(viewPortHandler) {
    this._legend = legend;

    _legendLabelPaint = PainterUtils.create(
        _legendLabelPaint, null, ColorUtils.BLACK, Utils.convertDpToPixel(9));

    _legendFormPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
  }

  // ignore: unnecessary_getters_setters
  Paint get legendFormPaint => _legendFormPaint;

  // ignore: unnecessary_getters_setters
  set legendFormPaint(Paint value) {
    _legendFormPaint = value;
  }

  Legend get legend => _legend;

  // ignore: unnecessary_getters_setters
  TextPainter get legendLabelPaint => _legendLabelPaint;

  // ignore: unnecessary_getters_setters
  set legendLabelPaint(TextPainter value) {
    _legendLabelPaint = value;
  }

  List<LegendEntry> _computedEntries = List(16);

  /// Prepares the legend and calculates all needed forms, labels and colors.
  ///
  /// @param data
  void computeLegend(ChartData<IDataSet> data) {
    if (!_legend.isLegendCustom) {
      _computedEntries = List();

      // loop for building up the colors and labels used in the legend
      for (int i = 0; i < data.getDataSetCount(); i++) {
        IDataSet dataSet = data.getDataSetByIndex(i);

        List<Color> clrs = dataSet.getColors();
        int entryCount = dataSet.getEntryCount();

        if (dataSet is IBarDataSet && dataSet.isStacked()) {
          IBarDataSet bds = dataSet;
          List<String> sLabels = bds.getStackLabels();

          for (int j = 0; j < clrs.length && j < bds.getStackSize(); j++) {
            _computedEntries.add(LegendEntry(
                sLabels[j % sLabels.length],
                dataSet.getForm(),
                dataSet.getFormSize(),
                dataSet.getFormLineWidth(),
                dataSet.getFormLineDashEffect(),
                clrs[j]));
          }

          if (bds.getLabel() != null) {
            // add the legend description label
            _computedEntries.add(LegendEntry(
                dataSet.getLabel(),
                LegendForm.NONE,
                double.nan,
                double.nan,
                null,
                ColorUtils.COLOR_NONE));
          }
        } else if (dataSet is IPieDataSet) {
          IPieDataSet pds = dataSet;

          for (int j = 0; j < clrs.length && j < entryCount; j++) {
            _computedEntries.add(LegendEntry(
                pds.getEntryForIndex(j).label,
                dataSet.getForm(),
                dataSet.getFormSize(),
                dataSet.getFormLineWidth(),
                dataSet.getFormLineDashEffect(),
                clrs[j]));
          }

          if (pds.getLabel() != null) {
            // add the legend description label
            _computedEntries.add(LegendEntry(
                dataSet.getLabel(),
                LegendForm.NONE,
                double.nan,
                double.nan,
                null,
                ColorUtils.COLOR_NONE));
          }
        } else if (dataSet is ICandleDataSet &&
            dataSet.getDecreasingColor() != ColorUtils.COLOR_NONE) {
          Color decreasingColor = dataSet.getDecreasingColor();
          Color increasingColor = dataSet.getIncreasingColor();

          _computedEntries.add(LegendEntry(
              null,
              dataSet.getForm(),
              dataSet.getFormSize(),
              dataSet.getFormLineWidth(),
              dataSet.getFormLineDashEffect(),
              decreasingColor));

          _computedEntries.add(LegendEntry(
              dataSet.getLabel(),
              dataSet.getForm(),
              dataSet.getFormSize(),
              dataSet.getFormLineWidth(),
              dataSet.getFormLineDashEffect(),
              increasingColor));
        } else {
          // all others

          for (int j = 0; j < clrs.length && j < entryCount; j++) {
            String label;

            // if multiple colors are set for a DataSet, group them
            if (j < clrs.length - 1 && j < entryCount - 1) {
              label = null;
            } else {
              // add label to the last entry
              label = data.getDataSetByIndex(i).getLabel();
            }

            _computedEntries.add(LegendEntry(
                label,
                dataSet.getForm(),
                dataSet.getFormSize(),
                dataSet.getFormLineWidth(),
                dataSet.getFormLineDashEffect(),
                clrs[j]));
          }
        }
      }

      if (_legend.extraEntries != null) {
        _computedEntries.addAll(_legend.extraEntries);
      }

      _legend.entries = (_computedEntries);
    }

    _legendLabelPaint = getLabelPainter();

    // calculate all dimensions of the _legend
    _legend.calculateDimensions(_legendLabelPaint, viewPortHandler);
  }

  TextPainter getLabelPainter() {
    var color = _legendLabelPaint.text.style.color;
    var fontSize = _legendLabelPaint.text.style.fontSize;
    var fontFamily = _legend.typeface?.fontFamily;
    var fontWeight = _legend.typeface?.fontWeight;
    return PainterUtils.create(_legendLabelPaint, null, color, fontSize,
        fontFamily: fontFamily, fontWeight: fontWeight);
  }

  void renderLegend(Canvas c) {
    if (!_legend.enabled) return;

    _legendLabelPaint = getLabelPainter();

    double labelLineHeight = Utils.getLineHeight1(_legendLabelPaint);
    double labelLineSpacing = Utils.getLineSpacing1(_legendLabelPaint) +
        Utils.convertDpToPixel(_legend.yEntrySpace);
    double formYOffset =
        labelLineHeight - Utils.calcTextHeight(_legendLabelPaint, "ABC") / 2;

    List<LegendEntry> entries = _legend.entries;

    double formToTextSpace = Utils.convertDpToPixel(_legend.formToTextSpace);
    double xEntrySpace = Utils.convertDpToPixel(_legend.xEntrySpace);
    LegendOrientation orientation = _legend.orientation;
    LegendHorizontalAlignment horizontalAlignment = _legend.horizontalAlignment;
    LegendVerticalAlignment verticalAlignment = _legend.verticalAlignment;
    LegendDirection direction = _legend.direction;
    double defaultFormSize = Utils.convertDpToPixel(_legend.formSize);

    // space between the entries
    double stackSpace = Utils.convertDpToPixel(_legend.stackSpace);

    double yoffset = _legend.yOffset;
    double xoffset = _legend.xOffset;
    double originPosX = 0;

    switch (horizontalAlignment) {
      case LegendHorizontalAlignment.LEFT:
        if (orientation == LegendOrientation.VERTICAL)
          originPosX = xoffset;
        else
          originPosX = viewPortHandler.contentLeft() + xoffset;

        if (direction == LegendDirection.RIGHT_TO_LEFT)
          originPosX += _legend.neededWidth;

        break;

      case LegendHorizontalAlignment.RIGHT:
        if (orientation == LegendOrientation.VERTICAL)
          originPosX = viewPortHandler.getChartWidth() - xoffset;
        else
          originPosX = viewPortHandler.contentRight() - xoffset;

        if (direction == LegendDirection.LEFT_TO_RIGHT)
          originPosX -= _legend.neededWidth;

        break;

      case LegendHorizontalAlignment.CENTER:
        if (orientation == LegendOrientation.VERTICAL)
          originPosX = viewPortHandler.getChartWidth() / 2;
        else
          originPosX = viewPortHandler.contentLeft() +
              viewPortHandler.contentWidth() / 2;

        originPosX +=
            (direction == LegendDirection.LEFT_TO_RIGHT ? xoffset : -xoffset);

        // Horizontally layed out legends do the center offset on a line basis,
        // So here we offset the vertical ones only.
        if (orientation == LegendOrientation.VERTICAL) {
          originPosX += (direction == LegendDirection.LEFT_TO_RIGHT
              ? -_legend.neededWidth / 2.0 + xoffset
              : _legend.neededWidth / 2.0 - xoffset);
        }

        break;
    }

    switch (orientation) {
      case LegendOrientation.HORIZONTAL:
        {
          List<FSize> calculatedLineSizes = _legend.calculatedLineSizes;
          List<FSize> calculatedLabelSizes = _legend.calculatedLabelSizes;
          List<bool> calculatedLabelBreakPoints =
              _legend.calculatedLabelBreakPoints;

          double posX = originPosX;
          double posY = 0;

          switch (verticalAlignment) {
            case LegendVerticalAlignment.TOP:
              posY = yoffset;
              break;

            case LegendVerticalAlignment.BOTTOM:
              posY = viewPortHandler.getChartHeight() -
                  yoffset -
                  _legend.neededHeight;
              break;

            case LegendVerticalAlignment.CENTER:
              posY = (viewPortHandler.getChartHeight() - _legend.neededHeight) /
                      2 +
                  yoffset;
              break;
          }

          int lineIndex = 0;

          for (int i = 0, count = entries.length; i < count; i++) {
            LegendEntry e = entries[i];
            bool drawingForm = e.form != LegendForm.NONE;
            double formSize = e.formSize.isNaN
                ? defaultFormSize
                : Utils.convertDpToPixel(e.formSize);

            if (i < calculatedLabelBreakPoints.length &&
                calculatedLabelBreakPoints[i]) {
              posX = originPosX;
              posY += labelLineHeight + labelLineSpacing;
            }

            if (posX == originPosX &&
                horizontalAlignment == LegendHorizontalAlignment.CENTER &&
                lineIndex < calculatedLineSizes.length) {
              posX += (direction == LegendDirection.RIGHT_TO_LEFT
                      ? calculatedLineSizes[lineIndex].width
                      : -calculatedLineSizes[lineIndex].width) /
                  2;
              lineIndex++;
            }

            bool isStacked = e.label == null; // grouped forms have null labels

            if (drawingForm) {
              if (direction == LegendDirection.RIGHT_TO_LEFT) posX -= formSize;

              drawForm(c, posX, posY + formYOffset, e, _legend);

              if (direction == LegendDirection.LEFT_TO_RIGHT) posX += formSize;
            }

            if (!isStacked) {
              if (drawingForm)
                posX += direction == LegendDirection.RIGHT_TO_LEFT
                    ? -formToTextSpace
                    : formToTextSpace;

              if (direction == LegendDirection.RIGHT_TO_LEFT)
                posX -= calculatedLabelSizes[i].width;

              drawLabel(c, posX, posY + labelLineHeight, e.label);

              if (direction == LegendDirection.LEFT_TO_RIGHT)
                posX += calculatedLabelSizes[i].width;

              posX += direction == LegendDirection.RIGHT_TO_LEFT
                  ? -xEntrySpace
                  : xEntrySpace;
            } else
              posX += direction == LegendDirection.RIGHT_TO_LEFT
                  ? -stackSpace
                  : stackSpace;
          }

          break;
        }

      case LegendOrientation.VERTICAL:
        {
          // contains the stacked legend size in pixels
          double stack = 0;
          bool wasStacked = false;
          double posY = 0;

          switch (verticalAlignment) {
            case LegendVerticalAlignment.TOP:
              posY = (horizontalAlignment == LegendHorizontalAlignment.CENTER
                  ? 0
                  : viewPortHandler.contentTop());
              posY += yoffset;
              break;

            case LegendVerticalAlignment.BOTTOM:
              posY = (horizontalAlignment == LegendHorizontalAlignment.CENTER
                  ? viewPortHandler.getChartHeight()
                  : viewPortHandler.contentBottom());
              posY -= _legend.neededHeight + yoffset;
              break;

            case LegendVerticalAlignment.CENTER:
              posY = viewPortHandler.getChartHeight() / 2 -
                  _legend.neededHeight / 2 +
                  _legend.yOffset;
              break;
          }

          for (int i = 0; i < entries.length; i++) {
            LegendEntry e = entries[i];
            bool drawingForm = e.form != LegendForm.NONE;
            double formSize = e.formSize.isNaN
                ? defaultFormSize
                : Utils.convertDpToPixel(e.formSize);

            double posX = originPosX;

            if (drawingForm) {
              if (direction == LegendDirection.LEFT_TO_RIGHT)
                posX += stack;
              else
                posX -= formSize - stack;

              drawForm(c, posX, posY + formYOffset, e, _legend);

              if (direction == LegendDirection.LEFT_TO_RIGHT) posX += formSize;
            }

            if (e.label != null) {
              if (drawingForm && !wasStacked)
                posX += direction == LegendDirection.LEFT_TO_RIGHT
                    ? formToTextSpace
                    : -formToTextSpace;
              else if (wasStacked) posX = originPosX;

              if (direction == LegendDirection.RIGHT_TO_LEFT)
                posX -= Utils.calcTextWidth(_legendLabelPaint, e.label);

              if (!wasStacked) {
                drawLabel(c, posX, posY + labelLineHeight, e.label);
              } else {
                posY += labelLineHeight + labelLineSpacing;
                drawLabel(c, posX, posY + labelLineHeight, e.label);
              }

              // make a step down
              posY += labelLineHeight + labelLineSpacing;
              stack = 0;
            } else {
              stack += formSize + stackSpace;
              wasStacked = true;
            }
          }
          break;
        }
    }
  }

  Path _lineFormPath = Path();

  /// Draws the Legend-form at the given position with the color at the given
  /// index.
  ///
  /// @param c      canvas to draw with
  /// @param x      position
  /// @param y      position
  /// @param entry  the entry to render
  /// @param legend the legend context
  void drawForm(
      Canvas c, double x, double y, LegendEntry entry, Legend legend) {
    if (entry.formColor == ColorUtils.COLOR_SKIP ||
        entry.formColor == ColorUtils.COLOR_NONE) return;

    c.save();

    LegendForm form = entry.form;
    if (form == LegendForm.DEFAULT) form = legend.shape;

    final double formSize = Utils.convertDpToPixel(
        entry.formSize.isNaN ? legend.formSize : entry.formSize);
    final double half = formSize / 2;

    switch (form) {
      case LegendForm.NONE:
        // Do nothing
        break;

      case LegendForm.EMPTY:
        // Do not draw, but keep space for the form
        break;

      case LegendForm.DEFAULT:
      case LegendForm.CIRCLE:
        _legendFormPaint = Paint()
          ..isAntiAlias = true
          ..color = entry.formColor
          ..style = PaintingStyle.fill;
        c.drawCircle(Offset(x + half, y), half, _legendFormPaint);
        break;

      case LegendForm.SQUARE:
        _legendFormPaint = Paint()
          ..isAntiAlias = true
          ..color = entry.formColor
          ..style = PaintingStyle.fill;
        c.drawRect(Rect.fromLTRB(x, y - half, x + formSize, y + half),
            _legendFormPaint);
        break;

      case LegendForm.LINE:
        {
          final double formLineWidth = Utils.convertDpToPixel(
              entry.formLineWidth.isNaN
                  ? legend.formLineWidth
                  : entry.formLineWidth);
          final DashPathEffect formLineDashEffect =
              entry.formLineDashEffect == null
                  ? legend.getFormLineDashEffect()
                  : entry.formLineDashEffect;
          _legendFormPaint = Paint()
            ..isAntiAlias = true
            ..color = entry.formColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = formLineWidth;
          _lineFormPath.reset();
          _lineFormPath.moveTo(x, y);
          _lineFormPath.lineTo(x + formSize, y);
          if (formLineDashEffect != null) {
            _lineFormPath = formLineDashEffect.convert2DashPath(_lineFormPath);
          }
          c.drawPath(_lineFormPath, _legendFormPaint);
        }
        break;
    }
    c.restore();
  }

  void drawLabel(Canvas c, double x, double y, String label) {
    _legendLabelPaint.text =
        TextSpan(text: label, style: _legendLabelPaint.text.style);
    _legendLabelPaint.layout();
    _legendLabelPaint.paint(c, Offset(x, y - _legendLabelPaint.height));
  }
}
