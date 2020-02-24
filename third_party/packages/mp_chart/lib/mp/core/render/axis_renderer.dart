import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:mp_chart/mp/core/axis/axis_base.dart';
import 'package:mp_chart/mp/core/poolable/point.dart';
import 'package:mp_chart/mp/core/render/renderer.dart';
import 'package:mp_chart/mp/core/transformer/transformer.dart';
import 'package:mp_chart/mp/core/utils/color_utils.dart';
import 'package:mp_chart/mp/core/utils/painter_utils.dart';
import 'package:mp_chart/mp/core/utils/utils.dart';
import 'package:mp_chart/mp/core/view_port.dart';

abstract class AxisRenderer extends Renderer {
  /// base axis this axis renderer works with */
  AxisBase _axis;

  /// transformer to transform values to screen pixels and return */
  Transformer _trans;

  /// paint object for the grid lines
  Paint _gridPaint;

  /// paint for the x-label values
  TextPainter _axisLabelPaint;

  /// paint for the line surrounding the chart
  Paint _axisLinePaint;

  /// paint used for the limit lines
  Paint _limitLinePaint;

  AxisRenderer(
      ViewPortHandler viewPortHandler, Transformer trans, AxisBase axis)
      : super(viewPortHandler) {
    this._trans = trans;
    this._axis = axis;
    if (viewPortHandler != null) {
      _gridPaint = Paint()
        ..color = Color.fromARGB(90, 160, 160, 160)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      _axisLabelPaint = PainterUtils.create(null, null, ColorUtils.BLACK, null);

      _axisLinePaint = Paint()..style = PaintingStyle.stroke;

      _limitLinePaint = Paint()..style = PaintingStyle.stroke;
    }
  }

  // ignore: unnecessary_getters_setters
  AxisBase get axis => _axis;

  // ignore: unnecessary_getters_setters
  set axis(AxisBase value) {
    _axis = value;
  }

  // ignore: unnecessary_getters_setters
  Transformer get trans => _trans;

  // ignore: unnecessary_getters_setters
  set trans(Transformer value) {
    _trans = value;
  }

  // ignore: unnecessary_getters_setters
  Paint get axisLinePaint => _axisLinePaint;

  // ignore: unnecessary_getters_setters
  set axisLinePaint(Paint value) {
    _axisLinePaint = value;
  }

  // ignore: unnecessary_getters_setters
  TextPainter get axisLabelPaint => _axisLabelPaint;

  // ignore: unnecessary_getters_setters
  set axisLabelPaint(TextPainter value) {
    _axisLabelPaint = value;
  }

  // ignore: unnecessary_getters_setters
  Paint get gridPaint => _gridPaint;

  // ignore: unnecessary_getters_setters
  set gridPaint(Paint value) {
    _gridPaint = value;
  }

  // ignore: unnecessary_getters_setters
  Paint get limitLinePaint => _limitLinePaint;

  // ignore: unnecessary_getters_setters
  set limitLinePaint(Paint value) {
    _limitLinePaint = value;
  }

  /// Computes the axis values.
  ///
  /// @param min - the minimum value in the data object for this axis
  /// @param max - the maximum value in the data object for this axis
  void computeAxis(double min, double max, bool inverted) {
    // calculate the starting and entry point of the y-labels (depending on
    // zoom / contentrect bounds)
    if (viewPortHandler != null &&
        viewPortHandler.contentWidth() > 10 &&
        !viewPortHandler.isFullyZoomedOutY()) {
      MPPointD p1 = _trans.getValuesByTouchPoint1(
          viewPortHandler.contentLeft(), viewPortHandler.contentTop());
      MPPointD p2 = _trans.getValuesByTouchPoint1(
          viewPortHandler.contentLeft(), viewPortHandler.contentBottom());

      if (!inverted) {
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

  /// Sets up the axis values. Computes the desired number of labels between the two given extremes.
  ///
  /// @return
  void computeAxisValues(double min, double max) {
    double yMin = min;
    double yMax = max;

    int labelCount = _axis.labelCount;
    double range = (yMax - yMin).abs();

    if (labelCount == 0 || range <= 0 || range.isInfinite) {
      _axis.entries = List<double>();
      _axis.centeredEntries = List<double>();
      _axis.entryCount = 0;
      return;
    }

    // Find out how much spacing (in y value space) between axis values
    double rawInterval = range / labelCount;
    double interval = Utils.roundToNextSignificant(rawInterval);

    // If granularity is enabled, then do not allow the interval to go below specified granularity.
    // This is used to avoid repeated values when rounding values for display.
    if (_axis.granularityEnabled)
      interval = interval < _axis.granularity ? _axis.granularity : interval;

    // Normalize interval
    double intervalMagnitude =
        Utils.roundToNextSignificant(pow(10.0, log(interval) ~/ ln10));
    int intervalSigDigit = interval ~/ intervalMagnitude;
    if (intervalSigDigit > 5) {
      // Use one order of magnitude higher, to avoid intervals like 0.9 or
      // 90
      interval = (10 * intervalMagnitude).floorToDouble();
    }

    int num = _axis.isCenterAxisLabelsEnabled() ? 1 : 0;

    // force label count
    if (_axis.forceLabels) {
      interval = range / (labelCount - 1);
      _axis.entryCount = labelCount;

      if (_axis.entries.length < labelCount) {
        // Ensure stops contains at least numStops elements.
        _axis.entries = List(labelCount);
      }

      double v = min;

      for (int i = 0; i < labelCount; i++) {
        _axis.entries[i] = v;
        v += interval;
      }

      num = labelCount;

      // no forced count
    } else {
      double first =
          interval == 0.0 ? 0.0 : (yMin / interval).ceil() * interval;
      if (_axis.isCenterAxisLabelsEnabled()) {
        first -= interval;
      }

      double last = interval == 0.0
          ? 0.0
          : Utils.nextUp((yMax / interval).floor() * interval);

      double f;
      int i;

      if (interval != 0.0) {
        for (f = first; f <= last; f += interval) {
          ++num;
        }
      }

      _axis.entryCount = num;

      if (_axis.entries.length < num) {
        // Ensure stops contains at least numStops elements.
        _axis.entries = List(num);
      }

      i = 0;
      for (f = first; i < num; f += interval, ++i) {
        if (f ==
            0.0) // Fix for negative zero case (Where value == -0.0, and 0.0 == -0.0)
          f = 0.0;

        _axis.entries[i] = f;
      }
    }

    // set decimals
    if (interval < 1) {
      _axis.decimals = (-log(interval) / ln10).ceil();
    } else {
      _axis.decimals = 0;
    }

    if (_axis.isCenterAxisLabelsEnabled()) {
      if (_axis.centeredEntries.length < num) {
        _axis.centeredEntries = List(num);
      }

      int offset = interval ~/ 2;

      for (int i = 0; i < num; i++) {
        _axis.centeredEntries[i] = _axis.entries[i] + offset;
      }
    }
  }

  /// Draws the axis labels to the screen.
  ///
  /// @param c
  void renderAxisLabels(Canvas c);

  /// Draws the grid lines belonging to the axis.
  ///
  /// @param c
  void renderGridLines(Canvas c);

  /// Draws the line that goes alongside the axis.
  ///
  /// @param c
  void renderAxisLine(Canvas c);

  /// Draws the LimitLines associated with this axis to the screen.
  ///
  /// @param c
  void renderLimitLines(Canvas c);
}
