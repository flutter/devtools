import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/adapter_android_mp.dart';
import 'package:mp_chart/mp/core/component.dart';
import 'package:mp_chart/mp/core/enums/legend_direction.dart';
import 'package:mp_chart/mp/core/enums/legend_form.dart';
import 'package:mp_chart/mp/core/enums/legend_horizontal_alignment.dart';
import 'package:mp_chart/mp/core/enums/legend_orientation.dart';
import 'package:mp_chart/mp/core/enums/legend_vertical_alignment.dart';
import 'package:mp_chart/mp/core/legend/legend_entry.dart';
import 'package:mp_chart/mp/core/poolable/size.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';

class Legend extends ComponentBase {
  /// The legend entries array
  List<LegendEntry> _entries = List();

  /// Entries that will be appended to the end of the auto calculated entries after calculating the legend.
  /// (if the legend has already been calculated, you will need to call notifyDataSetChanged() to let the changes take effect)
  List<LegendEntry> _extraEntries;

  /// Are the legend labels/colors a custom value or auto calculated? If false,
  /// then it's auto, if true, then custom. default false (automatic legend)
  bool _isLegendCustom = false;

  LegendHorizontalAlignment _horizontalAlignment =
      LegendHorizontalAlignment.LEFT;
  LegendVerticalAlignment _verticalAlignment = LegendVerticalAlignment.BOTTOM;
  LegendOrientation _orientation = LegendOrientation.HORIZONTAL;
  bool _drawInside = false;

  /// the text direction for the legend
  LegendDirection _direction = LegendDirection.LEFT_TO_RIGHT;

  /// the shape/form the legend colors are drawn in
  LegendForm _shape = LegendForm.SQUARE;

  /// the size of the legend forms/shapes
  double _formSize = 8;

  /// the size of the legend forms/shapes
  double _formLineWidth = 3;

  /// Line dash path effect used for shapes that consist of lines.
  DashPathEffect _formLineDashEffect;

  /// the space between the legend entries on a horizontal axis, default 6f
  double _xEntrySpace = 6;

  /// the space between the legend entries on a vertical axis, default 5f
  double _yEntrySpace = 0;

  /// the space between the legend entries on a vertical axis, default 2f
  ///  double _yEntrySpace = 2f;  the space between the form and the
  /// actual label/text
  double _formToTextSpace = 5;

  /// the space that should be left between stacked forms
  double _stackSpace = 3;

  /// the maximum relative size out of the whole chart view in percent
  double _maxSizePercent = 0.95;

  /// the total width of the legend (needed width space)
  double _neededWidth = 0;

  /// the total height of the legend (needed height space)
  double _neededHeight = 0;

  double _textHeightMax = 0;

  double _textWidthMax = 0;

  /// flag that indicates if word wrapping is enabled
  bool _wordWrapEnabled = false;

  List<FSize> _calculatedLabelSizes = List(16);
  List<bool> _calculatedLabelBreakPoints = List(16);
  List<FSize> _calculatedLineSizes = List(16);

  /// default constructor
  Legend() {
    this.textSize = Utils.convertDpToPixel(10);
    this.xOffset = Utils.convertDpToPixel(5);
    this.yOffset = Utils.convertDpToPixel(3); // 2
  }

  /// Constructor. Provide entries for the legend.
  ///
  /// @param entries
  Legend.fromList(List<LegendEntry> entries) {
    this.textSize = Utils.convertDpToPixel(10);
    this.xOffset = Utils.convertDpToPixel(5);
    this.yOffset = Utils.convertDpToPixel(3);
    if (entries == null) {
      throw new Exception("entries array is NULL");
    }

    this._entries = entries;
  }

  // ignore: unnecessary_getters_setters
  List<LegendEntry> get entries => _entries;

  // ignore: unnecessary_getters_setters
  set entries(List<LegendEntry> value) {
    _entries = value;
  }

  /// returns the maximum length in pixels across all legend labels + formsize
  /// + formtotextspace
  ///
  /// @param p the paint object used for rendering the text
  /// @return
  double getMaximumEntryWidth(TextPainter p) {
    double max = 0;
    double maxFormSize = 0;
    double formToTextSpace = Utils.convertDpToPixel(_formToTextSpace);
    for (LegendEntry entry in _entries) {
      final double formSize = Utils.convertDpToPixel(
          double.nan == entry.formSize ? _formSize : entry.formSize);
      if (formSize > maxFormSize) maxFormSize = formSize;

      String label = entry.label;
      if (label == null) continue;

      double length = Utils.calcTextWidth(p, label).toDouble();

      if (length > max) max = length;
    }

    return max + maxFormSize + formToTextSpace;
  }

  /// returns the maximum height in pixels across all legend labels
  ///
  /// @param p the paint object used for rendering the text
  /// @return
  double getMaximumEntryHeight(TextPainter p) {
    double max = 0;
    for (LegendEntry entry in _entries) {
      String label = entry.label;
      if (label == null) continue;

      double length = Utils.calcTextHeight(p, label).toDouble();

      if (length > max) max = length;
    }

    return max;
  }

  List<LegendEntry> get extraEntries => _extraEntries;

  void setExtra1(List<LegendEntry> entries) {
    _extraEntries = entries;
  }

  /// Entries that will be appended to the end of the auto calculated
  ///   entries after calculating the legend.
  /// (if the legend has already been calculated, you will need to call notifyDataSetChanged()
  ///   to let the changes take effect)
  void setExtra2(List<Color> colors, List<String> labels) {
    List<LegendEntry> entries = List();
    for (int i = 0; i < min(colors.length, labels.length); i++) {
      final LegendEntry entry = LegendEntry.empty();
      entry.formColor = colors[i];
      entry.label = labels[i];

      if (entry.formColor == ColorUtils.COLOR_SKIP)
        entry.form = LegendForm.NONE;
      else if (entry.formColor == ColorUtils.COLOR_NONE)
        entry.form = LegendForm.EMPTY;

      entries.add(entry);
    }

    _extraEntries = entries;
  }

  double get textHeightMax => _textHeightMax;

  double get textWidthMax => _textWidthMax;

  /// Sets a custom legend's entries array.
  /// * A null label will start a group.
  /// This will disable the feature that automatically calculates the legend
  ///   entries from the datasets.
  /// Call resetCustom() to re-enable automatic calculation (and then
  ///   notifyDataSetChanged() is needed to auto-calculate the legend again)
  void setCustom(List<LegendEntry> entries) {
    _entries = entries;
    _isLegendCustom = true;
  }

  /// Calling this will disable the custom legend entries (set by
  /// setCustom(...)). Instead, the entries will again be calculated
  /// automatically (after notifyDataSetChanged() is called).
  void resetCustom() {
    _isLegendCustom = false;
  }

  bool get isLegendCustom => _isLegendCustom;

  // ignore: unnecessary_getters_setters
  LegendHorizontalAlignment get horizontalAlignment => _horizontalAlignment;

  // ignore: unnecessary_getters_setters
  set horizontalAlignment(LegendHorizontalAlignment value) {
    _horizontalAlignment = value;
  }

  // ignore: unnecessary_getters_setters
  LegendVerticalAlignment get verticalAlignment => _verticalAlignment;

  // ignore: unnecessary_getters_setters
  set verticalAlignment(LegendVerticalAlignment value) {
    _verticalAlignment = value;
  }

  // ignore: unnecessary_getters_setters
  LegendOrientation get orientation => _orientation;

  // ignore: unnecessary_getters_setters
  set orientation(LegendOrientation value) {
    _orientation = value;
  }

  // ignore: unnecessary_getters_setters
  bool get drawInside => _drawInside;

  // ignore: unnecessary_getters_setters
  set drawInside(bool value) {
    _drawInside = value;
  }

  // ignore: unnecessary_getters_setters
  LegendDirection get direction => _direction;

  // ignore: unnecessary_getters_setters
  set direction(LegendDirection value) {
    _direction = value;
  }

  // ignore: unnecessary_getters_setters
  LegendForm get shape => _shape;

  // ignore: unnecessary_getters_setters
  set shape(LegendForm value) {
    _shape = value;
  }

  // ignore: unnecessary_getters_setters
  double get formSize => _formSize;

  // ignore: unnecessary_getters_setters
  set formSize(double value) {
    _formSize = value;
  }

  // ignore: unnecessary_getters_setters
  double get formLineWidth => _formLineWidth;

  // ignore: unnecessary_getters_setters
  set formLineWidth(double value) {
    _formLineWidth = value;
  }

  /// Sets the line dash path effect used for shapes that consist of lines.
  ///
  /// @param dashPathEffect
  void setFormLineDashEffect(DashPathEffect dashPathEffect) {
    _formLineDashEffect = dashPathEffect;
  }

  /// @return The line dash path effect used for shapes that consist of lines.
  DashPathEffect getFormLineDashEffect() {
    return _formLineDashEffect;
  }

  // ignore: unnecessary_getters_setters
  double get yEntrySpace => _yEntrySpace;

  // ignore: unnecessary_getters_setters
  set yEntrySpace(double value) {
    _yEntrySpace = value;
  }

  // ignore: unnecessary_getters_setters
  double get xEntrySpace => _xEntrySpace;

  // ignore: unnecessary_getters_setters
  set xEntrySpace(double value) {
    _xEntrySpace = value;
  }

  // ignore: unnecessary_getters_setters
  double get formToTextSpace => _formToTextSpace;

  // ignore: unnecessary_getters_setters
  set formToTextSpace(double value) {
    _formToTextSpace = value;
  }

  // ignore: unnecessary_getters_setters
  double get stackSpace => _stackSpace;

  // ignore: unnecessary_getters_setters
  set stackSpace(double value) {
    _stackSpace = value;
  }

  // ignore: unnecessary_getters_setters
  double get maxSizePercent => _maxSizePercent;

  // ignore: unnecessary_getters_setters
  set maxSizePercent(double value) {
    _maxSizePercent = value;
  }

  // ignore: unnecessary_getters_setters
  bool get wordWrapEnabled => _wordWrapEnabled;

  // ignore: unnecessary_getters_setters
  set wordWrapEnabled(bool value) {
    _wordWrapEnabled = value;
  }

  double get neededWidth => _neededWidth;

  double get neededHeight => _neededHeight;

  List<FSize> get calculatedLineSizes => _calculatedLineSizes;

  List<FSize> get calculatedLabelSizes => _calculatedLabelSizes;

  List<bool> get calculatedLabelBreakPoints => _calculatedLabelBreakPoints;

  /// Calculates the dimensions of the Legend. This includes the maximum width
  /// and height of a single entry, as well as the total width and height of
  /// the Legend.
  ///
  /// @param labelpaint
  void calculateDimensions(
      TextPainter labelpainter, ViewPortHandler viewPortHandler) {
    double defaultFormSize = Utils.convertDpToPixel(_formSize);
    double stackSpace = Utils.convertDpToPixel(_stackSpace);
    double formToTextSpace = Utils.convertDpToPixel(_formToTextSpace);
    double xEntrySpace = Utils.convertDpToPixel(_xEntrySpace);
    double yEntrySpace = Utils.convertDpToPixel(_yEntrySpace);
    bool wordWrapEnabled = _wordWrapEnabled;
    List<LegendEntry> entries = _entries;
    int entryCount = entries.length;

    _textWidthMax = getMaximumEntryWidth(labelpainter);
    _textHeightMax = getMaximumEntryHeight(labelpainter);

    switch (_orientation) {
      case LegendOrientation.VERTICAL:
        {
          double maxWidth = 0, maxHeight = 0, width = 0;
          double labelLineHeight = Utils.getLineHeight1(labelpainter);
          bool wasStacked = false;

          for (int i = 0; i < entryCount; i++) {
            LegendEntry e = entries[i];
            bool drawingForm = e.form != LegendForm.NONE;
            double formSize = e.formSize.isNaN
                ? defaultFormSize
                : Utils.convertDpToPixel(e.formSize);
            String label = e.label;

            if (!wasStacked) width = 0;

            if (drawingForm) {
              if (wasStacked) width += stackSpace;
              width += formSize;
            }

            // grouped forms have null labels
            if (label != null) {
              // make a step to the left
              if (drawingForm && !wasStacked)
                width += formToTextSpace;
              else if (wasStacked) {
                maxWidth = max(maxWidth, width);
                maxHeight += labelLineHeight + yEntrySpace;
                width = 0;
                wasStacked = false;
              }

              width += Utils.calcTextWidth(labelpainter, label);

              if (i < entryCount - 1)
                maxHeight += labelLineHeight + yEntrySpace;
            } else {
              wasStacked = true;
              width += formSize;
              if (i < entryCount - 1) width += stackSpace;
            }

            maxWidth = max(maxWidth, width);
          }

          _neededWidth = maxWidth;
          _neededHeight = maxHeight;

          break;
        }
      case LegendOrientation.HORIZONTAL:
        {
          double labelLineHeight = Utils.getLineHeight1(labelpainter);
          double labelLineSpacing =
              Utils.getLineSpacing1(labelpainter) + yEntrySpace;
          double contentWidth = viewPortHandler.chartWidth() * _maxSizePercent;

          // Start calculating layout
          double maxLineWidth = 0;
          double currentLineWidth = 0;
          double requiredWidth = 0;
          int stackedStartIndex = -1;

          _calculatedLabelBreakPoints = List();
          _calculatedLabelSizes = List();
          _calculatedLineSizes = List();

          for (int i = 0; i < entryCount; i++) {
            LegendEntry e = entries[i];
            bool drawingForm = e.form != LegendForm.NONE;
            double formSize = e.formSize.isNaN
                ? defaultFormSize
                : Utils.convertDpToPixel(e.formSize);
            String label = e.label;

            _calculatedLabelBreakPoints.add(false);

            if (stackedStartIndex == -1) {
              // we are not stacking, so required width is for this label
              // only
              requiredWidth = 0;
            } else {
              // add the spacing appropriate for stacked labels/forms
              requiredWidth += stackSpace;
            }

            // grouped forms have null labels
            if (label != null) {
              _calculatedLabelSizes
                  .add(Utils.calcTextSize1(labelpainter, label));
              requiredWidth += drawingForm ? formToTextSpace + formSize : 0;
              requiredWidth += _calculatedLabelSizes[i].width;
            } else {
              _calculatedLabelSizes.add(FSize.getInstance(0, 0));
              requiredWidth += drawingForm ? formSize : 0;

              if (stackedStartIndex == -1) {
                // mark this index as we might want to break here later
                stackedStartIndex = i;
              }
            }

            if (label != null || i == entryCount - 1) {
              double requiredSpacing = currentLineWidth == 0 ? 0 : xEntrySpace;

              if (!wordWrapEnabled // No word wrapping, it must fit.
                  // The line is empty, it must fit
                  ||
                  currentLineWidth == 0
                  // It simply fits
                  ||
                  (contentWidth - currentLineWidth >=
                      requiredSpacing + requiredWidth)) {
                // Expand current line
                currentLineWidth += requiredSpacing + requiredWidth;
              } else {
                // It doesn't fit, we need to wrap a line

                // Add current line size to array
                _calculatedLineSizes
                    .add(FSize.getInstance(currentLineWidth, labelLineHeight));
                maxLineWidth = max(maxLineWidth, currentLineWidth);

                // Start a new line
                _calculatedLabelBreakPoints.insert(
                    stackedStartIndex > -1 ? stackedStartIndex : i, true);
                currentLineWidth = requiredWidth;
              }

              if (i == entryCount - 1) {
                // Add last line size to array
                _calculatedLineSizes
                    .add(FSize.getInstance(currentLineWidth, labelLineHeight));
                maxLineWidth = max(maxLineWidth, currentLineWidth);
              }
            }

            stackedStartIndex = label != null ? -1 : stackedStartIndex;
          }

          _neededWidth = maxLineWidth;
          _neededHeight =
              labelLineHeight * (_calculatedLineSizes.length).toDouble() +
                  labelLineSpacing *
                      (_calculatedLineSizes.length == 0
                          ? 0
                          : (_calculatedLineSizes.length - 1));

          break;
        }
    }
    _neededHeight += yOffset;
    _neededWidth += xOffset;
  }
}
